package RInit::App;
our $VERSION = '0.1.0';

use strict;
use warnings;
use File::Path qw(make_path);
use File::Spec;
use File::Basename;
use Cwd;
use File::Copy;
use RInit::Templates;
use Getopt::Long qw(GetOptionsFromArray);
use Term::ANSIColor;
use Pod::Usage;

#' Main entry point for the RInit application
#'
#' Parses command-line arguments, validates input, and orchestrates
#' the creation of a new R project with standardized structure.
#'
#' @param $class The class name (unused in this implementation)
#' @param @args Command-line arguments array
#' @return void
#' @dies on invalid input or directory conflicts
sub run {
  my ( $class, @args ) = @_;

  my $lang  = 'en';
  my $help  = 0;
  my $setup = 0;

  # Parse command-line options from provided array
  GetOptionsFromArray(
    \@args,
    'lang=s' => \$lang,
    'setup'  => \$setup,
    'help|?' => \$help
    )
    or pod2usage( -exitval => 2, -input => __FILE__ );

  pod2usage( -exitval => 0, -verbose => 2, -input => __FILE__ ) if $help;

  if ($setup) {
    _run_setup();
    exit 0;
  }

  # Extract project name from remaining arguments
  my $project_name = shift @args;

  unless ($project_name) {
    print colored( ['red'], "Error: Please provide a project name" ), "\n";
    pod2usage( -exitval => 1, -input => __FILE__ );
  }

  # Construct project root directory path
  my $root_dir = File::Spec->catdir( getcwd(), $project_name );
  _check_directory_exists( $project_name, $root_dir );

  print colored( ['blue'], "🚀 Initializing R project: $project_name ..." ), "\n";

  # Execute project setup steps
  _create_directory_structure( $root_dir, $project_name );
  _create_config_files( $project_name, $root_dir, $lang );
  _initialize_version_control($root_dir);
  _show_completion_message($project_name);

  return;
}

sub _run_setup {
  require RInit::Manifest;

  print colored( ['blue'], "🔧 Setting up user templates..." ), "\n";

  # We need to bypass the priority check in Manifest to find the *source* share dir
  # Currently Manifest->_find_share_dir will return the user dir if it exists!
  # So we must temporarily unset env or look harder.
  # Actually, if we are setting UP, we want the DIST share dir, not the user one.
  # But Manifest->_find_share_dir is designed to return the best one.
  # We should probably expose a way to get the dist share dir or just find it here.
  # A trick is to modify Manifest to allow skipping the user check, or just implement a custom finder here.
  # Reusing _find_share_dir is risky if the user dir already exists partially.

  # Let's try to find the distribution share directory explicitly.
  # We can copy the logic from Manifest but skip the user_share check.

  my $source_dir;

  # Check development mode first
  my $dir = File::Basename::dirname(__FILE__);
  while ( $dir && $dir ne '/' && $dir !~ m{^[a-z]:[/\\]?$}i ) {
    my $candidate = File::Spec->catdir( $dir, 'share' );
    if ( -d $candidate && -f File::Spec->catfile( $dir, 'Makefile.PL' ) ) {
      $source_dir = $candidate;
      last;
    }
    my $parent = File::Basename::dirname($dir);
    last if $parent eq $dir;
    $dir = $parent;
  }

  # If not found, check File::ShareDir
  unless ($source_dir) {
    eval { require File::ShareDir; };
    unless ($@) {
      my $dist_dir = eval { File::ShareDir::dist_dir('RInit') };
      if ( $dist_dir && -d $dist_dir ) {
        $source_dir = $dist_dir;
      }
    }
  }

  # Fallback to relative to script
  if ( !$source_dir ) {
    my $script_dir = File::Basename::dirname($0);    # This might be bin/
    if ( my $check = File::Spec->catdir( $script_dir, '..', 'share' ) ) {
      $source_dir = $check if -d $check;
    }
  }

  unless ( $source_dir && -d $source_dir ) {
    die "Could not locate source 'share' directory to copy from.";
  }

  my $xdg_data_home = $ENV{XDG_DATA_HOME} || File::Spec->catdir( $ENV{HOME}, '.local', 'share' );
  my $target_dir    = File::Spec->catdir( $xdg_data_home, 'Rinit' );

  print "Source: $source_dir\n";
  print "Target: $target_dir\n";

  make_path($target_dir);

  # Find all files in source
  use File::Find;
  my $overwrite_all = 0;
  my $skip_all      = 0;

  find(
    sub {
      return if -d $_;
      my $rel      = File::Spec->abs2rel( $File::Find::name, $source_dir );
      my $dest     = File::Spec->catfile( $target_dir, $rel );
      my $dest_dir = File::Basename::dirname($dest);

      make_path($dest_dir) unless -d $dest_dir;

      if ( -e $dest ) {
        return if $skip_all;

        unless ($overwrite_all) {
          print colored( ['yellow'], "Conflict: $rel exists.\n" );
          print "Overwrite? [y]es, [n]o, [a]ll, [N]one (skip set): ";
          my $ans = <STDIN>;

          # Handle EOF (e.g. pipe closed) by skipping remaining
          unless ( defined $ans ) {
            $skip_all = 1;
            return;
          }

          chomp $ans;

          if ( $ans =~ /^a/i ) {
            $overwrite_all = 1;
          }
          elsif ( $ans =~ /^N/i ) {
            $skip_all = 1;
            return;
          }
          elsif ( $ans =~ /^n/i ) {
            return;
          }

          # Default is no overwrite if they just hit enter (empty string)
          return if $ans eq '';
        }
      }

      copy( $File::Find::name, $dest ) or warn "Failed to copy $_: $!\n";
      print "Copied $rel\n";

    },
    $source_dir
  );

  print colored( ['green'], "Setup complete!" ), "\n";
  return;
}

#' Verify that the target directory does not already exist
#'
#' @param $project_name The name of the project
#' @param $root_dir The full path to the project directory
#' @return void
#' @dies if directory already exists
sub _check_directory_exists {
  my ( $project_name, $root_dir ) = @_;

  if ( -d $root_dir ) {
    print colored( ['red'], "Error: Directory '$project_name' already exists" ), "\n";
    exit 1;
  }
  return;
}

#' Create the standard R project directory structure
#'
#' Uses RInit::Manifest to determine which directories to create.
#'
#' @param $root_dir The root directory path for the project
#' @param $project_name The name of the project
#' @return void
#' @dies if directory creation fails
sub _create_directory_structure {
  my ( $root_dir, $project_name ) = @_;

  make_path($root_dir) or die "Cannot create directory: $!";

  require RInit::Manifest;
  my $dirs = RInit::Manifest->get_dirs($project_name);

  # Create each directory in the manifest
  for my $dir (@$dirs) {
    make_path( File::Spec->catdir( $root_dir, $dir ) )
      or die "Cannot create directory '$dir': $!";
  }

  print colored( ['green'], "✅ Directory structure created" ), "\n";
  return;
}

#' Generate and write project configuration files
#'
#' Retrieves file templates from RInit::Templates and writes them
#' to the appropriate locations in the project structure.
#'
#' @param $project_name The name of the project
#' @param $root_dir The root directory path
#' @param $lang Language code for localized templates
#' @return void
#' @dies if file operations fail
sub _create_config_files {
  my ( $project_name, $root_dir, $lang ) = @_;

  my $operations = RInit::Templates->get_project_files( $project_name, $lang );

  for my $op (@$operations) {
    my $target = File::Spec->catfile( $root_dir, $op->{target} );
    _ensure_dir($target);

    if ( $op->{source} ) {
      copy( $op->{source}, $target ) or die "Copy failed: $!";    # Copy from source file
    }
    elsif ( defined $op->{content} ) {
      _write_file( $target, $op->{content} );                     # Write content directly
    }
  }

  print colored( ['green'], "✅ Configuration files created" ), "\n";
  return;
}

#' Ensure parent directory exists for a given file path
#'
#' @param $filename The full path to a file
#' @return void
#' @dies if directory creation fails
sub _ensure_dir {
  my ($filename) = @_;
  my $dir = dirname($filename);

  if ( $dir && !-d $dir ) {
    make_path($dir) or die "Cannot create directory '$dir': $!";
  }
  return;
}

#' Write content to a file
#'
#' @param $filename The path to the file to write
#' @param $content The content to write to the file
#' @return void
#' @dies if file cannot be opened or written
sub _write_file {
  my ( $filename, $content ) = @_;

  open my $fh, '>', $filename or die "Cannot write to $filename: $!";
  print $fh $content;
  close $fh or die "Cannot close $filename: $!";

  return;
}

#' Initialize version control systems (Git and DVC)
#'
#' Sets up Git repository with a subtree for r-box utilities,
#' and optionally initializes DVC for data versioning.
#'
#' @param $root_dir The root directory of the project
#' @return void
#' @dies if directory operations fail
sub _initialize_version_control {
  my ($root_dir) = @_;

  # Validate input
  die "Root directory not specified"         unless defined $root_dir;
  die "Directory '$root_dir' does not exist" unless -d $root_dir;

  # Change to project directory
  my $original_dir = getcwd();
  chdir($root_dir) or die "Cannot change to directory '$root_dir': $!";

  # Initialize Git if available
  if ( _command_exists('git') ) {

    # Initialize git, add files, and create initial commit
    my $git_init_cmd = 'git init -q && git add . && git commit -q -m "Initial commit"';

    if ( system($git_init_cmd) == 0 ) {
      print colored( ['green'], "✅ Git repository initialized" ), "\n";

      # Add the r-box subtree
      if ( _prompt_confirm("Do you want to add the r-box subtree (utils)?") ) {
        my $box_remote  = 'git@github.com:liubianshi/r-box.git';
        my $box_branch  = "master";
        my $subtree_cmd = "git remote add box-remote $box_remote && "
          . "git subtree add --prefix=r-box $box_remote $box_branch --squash 2>&1";
        if ( system($subtree_cmd) != 0 ) {
          print colored( ['yellow'], "⚠️  Failed to add r-box subtree (check network connection)" ), "\n";
        }
      }
      else {
        print colored( ['blue'], "ℹ️  Skipping r-box subtree" ), "\n";
      }
    }
    else {
      print colored( ['yellow'], "⚠️  Git initialization failed" ), "\n";
    }
  }
  else {
    print colored( ['red'], "⚠️  Git not found, skipping Git initialization" ), "\n";
  }

  # Initialize DVC if available
  if ( _command_exists('dvc') ) {
    if ( system('dvc init --quiet 2>&1') == 0 ) {
      print colored( ['green'], "✅ DVC (Data Version Control) initialized" ), "\n";
    }
    else {
      print colored( ['yellow'], "⚠️  DVC initialization failed" ), "\n";
    }
  }
  else {
    print colored( ['blue'], "ℹ️  DVC not detected. For large datasets (>100MB), install DVC: pip install dvc" ), "\n";
  }

  # Return to original directory
  chdir($original_dir) or die "Cannot return to original directory: $!";

  return;
}

#' Check if a command exists in the system PATH
#'
#' Uses 'command -v' for portable command existence checking
#' without executing the command.
#'
#' @param $cmd The command name to check
#' @return Boolean: 1 if command exists, 0 otherwise
sub _command_exists {
  my ($cmd) = @_;

  # Validate command name to prevent injection
  return 0 unless defined $cmd && $cmd =~ /^[\w-]+$/;

  # Use command -v for portable existence check
  return system("command -v $cmd > /dev/null 2>&1") == 0;
}

#' Display project initialization completion message
#'
#' @param $project_name The name of the initialized project
#' @return void
sub _show_completion_message {
  my ($project_name) = @_;

  print "\n", colored( ['blue'], "🎉 Project '$project_name' initialized successfully!" ), "\n";
  print "👉 Next steps:\n";
  print "   cd $project_name\n";
  print "   Or run: R\n";

  return;
}

#' Prompt user for confirmation (default No)
#'
#' @param $question The question to ask
#' @return Boolean: 1 for Yes, 0 for No
sub _prompt_confirm {
  my ($question) = @_;
  print colored( ['cyan'], "$question [y/N]: " );
  my $ans = <STDIN>;
  chomp $ans if defined $ans;
  return $ans && $ans =~ /^y/i;
}

1;

__END__

=head1 NAME

rinit - A modern R project scaffolding tool

=head1 SYNOPSIS

rinit [options] [project_name]

 Options:
   --help, -?       Show this help message
   --lang           Specify language variant (en/zh, default: en)

=head1 DESCRIPTION

B<rinit> initializes a new R project with a standardized directory structure,
useful defaults, and optional configuration for different languages.

It sets up:
-   Standard directory structure (R/, data/, out/, etc.)
-   Git and DVC version control
-   Quarto/RMarkdown templates
-   Dependency management with renv

=head1 ARGUMENTS

=over 4

=item B<project_name>

The name of the directory to create for the new project.

=back

=head1 OPTIONS

=over 4

=item B<--lang>

Optional language code ('en' or 'zh'). Defaults to 'en'.

=item B<--help>

Print a brief help message and exits.

=back

=head1 EXAMPLES

 rinit my_analysis
 rinit --lang zh my_analysis
 rinit --help

=cut

