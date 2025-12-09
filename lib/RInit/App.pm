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

sub run {
  my ( $class, @args ) = @_;

  my $lang = 'en';
  my $help = 0;
  
  # Parse arguments from the passed array, not @ARGV
  GetOptionsFromArray(
    \@args,
    'lang=s' => \$lang,
    'help|?' => \$help
  ) or pod2usage( -exitval => 2, -input => __FILE__ );

  pod2usage( -exitval => 0, -verbose => 2, -input => __FILE__ ) if $help;

  # Remaining argument is project name
  my $project_name = shift @args;
  
  unless ($project_name) {
    print colored(['red'], "Error: Please provide a project name"), "\n";
    pod2usage( -exitval => 1, -input => __FILE__ );
  }

  # Setup project paths
  my $root_dir = File::Spec->catdir( getcwd(), $project_name );
  check_directory_exists( $project_name, $root_dir );

  print colored(['blue'], "🚀 Initializing R project: $project_name ..."), "\n";

  # Create project structure
  create_directory_structure( $root_dir, $project_name );

  # Create configuration files
  create_config_files( $project_name, $root_dir, $lang );

  # Initialize version control
  initialize_version_control($root_dir);

  # Show completion message
  show_completion_message($project_name);
}

sub check_directory_exists {
  my ( $project_name, $root_dir ) = @_;

  if ( -d $root_dir ) {
    print colored(['red'], "Error: Directory '$project_name' already exists"), "\n";
    exit 1;
  }
}

sub create_directory_structure {
  my ( $root_dir, $project_name ) = @_;

  make_path($root_dir) or die "Cannot create directory: $!";
  
  require RInit::Manifest;
  my $dirs = RInit::Manifest->get_dirs( $project_name );

  # Create core directories
  for my $dir (@$dirs) {
      make_path(File::Spec->catdir($root_dir, $dir));
  }

  print colored(['green'], "✅ Directory structure created"), "\n";
}

sub create_config_files {
  my ( $project_name, $root_dir, $lang ) = @_;

  my $operations = RInit::Templates->get_project_files($project_name, $lang);

  for my $op (@$operations) {
    my $target = File::Spec->catfile($root_dir, $op->{target});
    _ensure_dir($target);

    if ( $op->{source} ) {
      copy( $op->{source}, $target ) or die "Copy failed: $!";
    }
    elsif ( defined $op->{content} ) {
      _write_file( $target, $op->{content} );
    }
  }

  print colored(['green'], "✅ Configuration files created"), "\n";
}

sub _ensure_dir {
  my ($filename) = @_;
  my $dir = dirname($filename);
  if ( $dir && !-d $dir ) {
    make_path($dir) or die "Cannot create directory '$dir': $!";
  }
}

sub _write_file {
  my ( $filename, $content ) = @_;
  open my $fh, '>', $filename or die "Cannot write to $filename: $!";
  print $fh $content;
  close $fh;
}

sub initialize_version_control {
  my ($root_dir) = @_;
  
  chdir($root_dir) or die "Cannot change to directory '$root_dir': $!";

  # Initialize Git
  if ( system("git --version > /dev/null 2>&1") == 0 ) {
    system("git init -q");
    print colored(['green'], "✅ Git repository initialized"), "\n";
  }
  else {
    print colored(['red'], "⚠️  Git not found, skipping Git initialization"), "\n";
  }

  # Initialize DVC
  if ( system("dvc version > /dev/null 2>&1") == 0 ) {
    system("dvc init --quiet");
    print colored(['green'], "✅ DVC (Data Version Control) initialized"), "\n";
  }
  else {
    print colored(['blue'], "ℹ️  DVC not detected. For large datasets (>100MB), install DVC: pip install dvc"), "\n";
  }
}

sub show_completion_message {
  my ($project_name) = @_;

  print "\n", colored(['blue'], "🎉 Project '$project_name' initialized successfully!"), "\n";
  print "👉 Next steps:\n";
  print "   cd $project_name\n";

  print "   Or run: R\n";
}

1;

__END__

=head1 NAME

rinit - A modern R project scaffolding tool

=head1 SYNOPSIS

rinit [options] [project_name] [language]

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
-   dependency management with renv

=head1 ARGUMENTS

=over 4

=item B<project_name>

The name of the directory to create for the new project.

=item B<language>

Optional language code ('en' or 'zh'). Defaults to 'en'.

=back

=head1 OPTIONS

=over 4

=item B<--help>

Print a brief help message and exits.

=back

=head1 EXAMPLES

 rinit my_analysis
 rinit my_analysis zh
 rinit --help

=cut