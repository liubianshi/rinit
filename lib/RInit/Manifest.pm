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

=cut

=head2 get_dirs

Returns a list of directories to be created for the project.

    my $dirs = RInit::Manifest->get_dirs($project_name, $variant);

=cut

sub get_dirs {
  my ( $class, $project_name, $variant ) = @_;
  return [
    'raw',
    'R/import',
    'R/build',
    'R/analysis',
    'R/check',
    'R/utils',
    'R/lib',
    'doc',
    'out/data',
    'out/tables',
    'out/figures',
    'out/manuscript',
    'log',
    'cache',
    '.pandoc'
  ];
}

sub get_files {
  my ( $class, $project_name, $variant ) = @_;
  $variant ||= 'en';

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

    my $target = $rel_path;

    # Rename gitignore to .gitignore for proper dotfile handling
    $target = '.gitignore' if $target eq 'gitignore';

    my $file_def = { target => $target, source => $abs_path, };

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
    1. RINIT_SHARE_DIR environment variable
    2. Development directory (walks up from current file)
    3. Installed distribution directory (via File::ShareDir)

Returns:
    String path to the share directory

Dies if the share directory cannot be located.

=cut

sub _find_share_dir {

  # 1. Check environment variable override
  return $ENV{RINIT_SHARE_DIR}
    if $ENV{RINIT_SHARE_DIR} && _is_valid_share($ENV{RINIT_SHARE_DIR});

  # 2. Development mode: walk up directory tree to find share/ with Makefile.PL
  # Use abs_path to ensure we are dealing with absolute paths, protecting against
  # issues where __FILE__ is relative and the current working directory changes.
  my $dir = abs_path(dirname(__FILE__));
  my @checked_dirs;

  while ( $dir && $dir ne '/' && $dir !~ m{^[a-z]:[/\\]?$}i ) {
    my $candidate = File::Spec->catdir( $dir, 'share' );
    
    push @checked_dirs, $candidate;

    # Verify this is a development directory by checking for Makefile.PL and valid share
    if ( -d $candidate && -f File::Spec->catfile( $dir, 'Makefile.PL' ) && _is_valid_share($candidate) ) {
      return $candidate;
    }

    my $parent = dirname($dir);
    last if $parent eq $dir;    # Reached filesystem root
    $dir = $parent;
  }

  # 2b. Check current working directory and parents (useful when running from repo root)
  my $cwd_dir = abs_path(getcwd());
  while ( $cwd_dir && $cwd_dir ne '/' && $cwd_dir !~ m{^[a-z]:[/\\]?$}i ) {
    my $candidate = File::Spec->catdir( $cwd_dir, 'share' );
    if ( _is_valid_share($candidate) ) {
      return $candidate;
    }
    my $parent = dirname($cwd_dir);
    last if $parent eq $cwd_dir;
    $cwd_dir = $parent;
  }

  # 3. Installed distribution: use File::ShareDir if available
  eval { require File::ShareDir; };
  unless ($@) {
    my $dist_dir = eval { File::ShareDir::dist_dir('RInit') };
    if ( $dist_dir && _is_valid_share($dist_dir) ) {
        return $dist_dir;
    }
  }

  # 4. Fallback: Check standard system locations
  for my $sys_dir ( '/usr/local/share/rinit', '/usr/share/rinit' ) {
      if ( _is_valid_share($sys_dir) ) {
          return $sys_dir;
      }
      push @checked_dirs, $sys_dir;
  }

  # 5. Fallback: Check for auto/share/dist/RInit relative to typical lib paths
  # This handles cases where File::ShareDir fails but the files are in the standard perl location
  for my $inc_path (@INC) {
      my $auto_share = File::Spec->catdir($inc_path, 'auto', 'share', 'dist', 'RInit');
      if ( _is_valid_share($auto_share) ) {
          return $auto_share;
      }
      push @checked_dirs, $auto_share;
  }

  # 6. Fallback: Check relative to the executing script ($0)
  # This helps when the module is loaded from @INC (e.g. installed lib) 
  # but the script is running from the repo bin/ or a known location where share/ is nearby.
  my $script_dir = abs_path(dirname($0));
  my $script_based_share = File::Spec->catdir($script_dir, '..', 'share');
  push @checked_dirs, $script_based_share;
  
  if ( _is_valid_share($script_based_share) ) {
      return $script_based_share;
  }
  
  my $checked_str = join("\n  ", @checked_dirs);
  die "Could not locate 'share' directory.\nChecked locations:\n  $checked_str\nSet RINIT_SHARE_DIR or install properly.\n";
}

sub _is_valid_share {
    my ($dir) = @_;
    return 0 unless -d $dir;
    # Check for specific files/dirs that must exist in our share directory
    return -d File::Spec->catdir($dir, 'metadata');
}

1;

=head1 AUTHOR

RInit Development Team

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
