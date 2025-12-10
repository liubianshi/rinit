package RInit::Manifest;

use strict;
use warnings;
use File::Find;
use File::Spec;
use File::Basename;
use Cwd qw(abs_path getcwd);

=head1 NAME

RInit::Manifest - File manifest management for RInit project initialization

=head1 SYNOPSIS

    my $files = RInit::Manifest->get_files('MyProject', 'en');

=head1 DESCRIPTION

This module handles the discovery and processing of template files for
project initialization, including metadata selection and file transformations.

=cut

=head2 get_dirs

Returns a list of directories to be created for the project.

    my $dirs = RInit::Manifest->get_dirs($project_name, $variant);

Parameters:
    $class        - Class name (method called as class method)
    $project_name - Name of the project being initialized (unused)
    $variant      - Language/variant code (unused)

Returns:
    ArrayRef of directory paths to create

=cut

sub get_dirs {
  my ( $class, $project_name, $variant ) = @_;
  
  # Return standard R project directory structure
  return [
    'raw',         'R/import',       'R/build',   'R/analysis', 'R/check',
    'R/utils',     'R/lib',          'doc',       'out/data',   'out/tables',
    'out/figures', 'out/manuscript', 'log',       'cache',      '.pandoc'
  ];
}

=head2 get_files

Retrieves and processes template files for project initialization.

    my $files = RInit::Manifest->get_files($project_name, $variant);

Parameters:
    $class        - Class name (method called as class method)
    $project_name - Name of the project being initialized
    $variant      - Language/variant code (default: 'en')

Returns:
    ArrayRef of hashrefs containing:
        - target:  Destination path for the file
        - source:  Source path of the template file
        - process: Optional code ref for content transformation

Dies if the share directory cannot be found.

=cut

sub get_files {
  my ( $class, $project_name, $variant ) = @_;
  $variant ||= 'en';

  # Locate the template directory
  my $share_dir = _find_share_dir();
  die "Cannot find 'share' template directory at $share_dir" unless -d $share_dir;

  my @files;

  # Closure to process each file found in the share directory
  my $loader = sub {
    return if -d $_;    # Skip directories

    my $abs_path = $File::Find::name;
    my $rel_path = File::Spec->abs2rel( $abs_path, $share_dir );

    # Skip metadata files (handled separately below)
    return if $rel_path =~ m{^metadata/};

    # Determine target filename
    my $target = $rel_path;
    $target = '.gitignore' if $target eq 'gitignore';  # Rename for proper dotfile handling

    my $file_def = {
      target => $target,
      source => $abs_path,
    };

    # Add content processor for README.md to substitute project name
    if ( $target eq 'README.md' ) {
      $file_def->{process} = sub {
        my ($content) = @_;
        $content =~ s/__PROJECT_NAME__/$project_name/g;
        return $content;
      };
    }

    push @files, $file_def;
  };

  # Traverse the share directory to collect files
  find( $loader, $share_dir );

  # Add variant-specific metadata file
  my $metadata_file = File::Spec->catfile( $share_dir, 'metadata', "metadata_${variant}.yml" );

  if ( -f $metadata_file ) {
    push @files,
      {
        target => '_metadata.yml',
        source => $metadata_file,
      };
  }
  else {
    warn "Metadata file for variant '$variant' not found at $metadata_file\n";
  }

  return \@files;
}

=head2 _find_share_dir

Locates the share directory containing template files.

Searches in the following order:
    1. User data directory (XDG_DATA_HOME or ~/.local/share)
    2. RINIT_SHARE_DIR environment variable
    3. Development directory (walks up from current file)
    4. Installed distribution directory (via File::ShareDir)

Returns:
    String path to the share directory

Dies if the share directory cannot be located.

=cut

sub _find_share_dir {

  # Define search strategies in priority order
  my @strategies = (
    \&_check_user_share,
    \&_check_env_share,
    \&_check_dev_share,
    \&_check_dist_share,
  );

  # Try each strategy until a valid share directory is found
  for my $strategy (@strategies) {
    if ( my $dir = $strategy->() ) {
      return $dir if _is_valid_share($dir);
    }
  }

  # No valid share directory found
  die "Could not locate 'share' directory.\n"
    . "Checked: User data dir, RINIT_SHARE_DIR, Development path, and File::ShareDir.\n";
}

=head2 _check_user_share

Checks for share directory in user's data directory.

Returns:
    String path to user share directory or undef

=cut

sub _check_user_share {
  my $xdg_data_home = $ENV{XDG_DATA_HOME} || File::Spec->catdir( $ENV{HOME}, '.local', 'share' );
  return File::Spec->catdir( $xdg_data_home, 'Rinit' );
}

=head2 _check_env_share

Checks for share directory via RINIT_SHARE_DIR environment variable.

Returns:
    String path from environment variable or undef

=cut

sub _check_env_share {
  return $ENV{RINIT_SHARE_DIR};
}

=head2 _check_dev_share

Checks for share directory in development tree.

Walks up from the current file location to find a share/ directory
adjacent to Makefile.PL (indicating project root).

Returns:
    String path to development share directory or undef

=cut

sub _check_dev_share {

  # Walk up from current file to find share/ with Makefile.PL
  my $dir = abs_path( dirname(__FILE__) );
  
  while ( $dir && $dir ne '/' && $dir !~ m{^[a-z]:[/\\]?$}i ) {
    my $candidate = File::Spec->catdir( $dir, 'share' );

    # Check for Makefile.PL to confirm it's a project root
    if ( -d $candidate && -f File::Spec->catfile( $dir, 'Makefile.PL' ) ) {
      return $candidate;
    }

    # Move up one directory level
    my $parent = dirname($dir);
    last if $parent eq $dir;  # Reached filesystem root
    $dir = $parent;
  }
  
  return undef;
}

=head2 _check_dist_share

Checks for share directory in installed distribution.

Uses File::ShareDir to locate the installed share directory.

Returns:
    String path to distribution share directory or undef

=cut

sub _check_dist_share {
  eval { require File::ShareDir; };
  return if $@;
  return eval { File::ShareDir::dist_dir('RInit') };
}

=head2 _is_valid_share

Validates that a directory is a valid share directory.

Parameters:
    $dir - Directory path to validate

Returns:
    Boolean - true if directory contains required structure

=cut

sub _is_valid_share {
  my ($dir) = @_;
  return 0 unless -d $dir;

  # Check for specific subdirectories that must exist in our share directory
  return -d File::Spec->catdir( $dir, 'metadata' );
}

1;

=head1 AUTHOR

RInit Development Team

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
