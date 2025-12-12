use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use File::Basename;

use File::Spec;
use File::Path qw(remove_tree);
use Cwd;
use FindBin;
use lib "$FindBin::Bin/../lib";
use RInit::App;

# plan tests => 5;

# Create a temporary directory for the test
my $temp_dir     = tempdir( CLEANUP => 1 );
my $original_cwd = getcwd();

# Switch to temp directory
chdir($temp_dir) or die "Cannot chdir to $temp_dir: $!";

# Test Project Name
my $project_name = "TestProject";

# Run the application (mocking arguments)
# We need to capture stdout/stderr to avoid cluttering test output,
# but for simplicity in this basic test we'll just let it print or redirect if needed.
# To properly test, we might want to capture output, but checking file existence is more critical.

# Validating results
# App.pm changes directory to the created project, so we verify files relative to the new CWD
# or we can check absolute paths.

# Handle the prompt by mocking STDIN with "n" (skip subtree)
{
  open my $stdin, '<', \ "n\n";
  local *STDIN = $stdin;
  eval { RInit::App->run($project_name); };
}
if ($@) {
  diag("Error running App: $@");
}
ok( !$@, "App ran without dying" );

# The application should NOT change the CWD of the caller.
# So we need to manually enter the project directory to verify its contents.
chdir($project_name) or die "Cannot chdir to $project_name: $!";
my $db_name = basename( getcwd() );
is( $db_name, $project_name, "Verified we are in project dir" );

ok( -f "R/main.R",     "R/main.R created" );
ok( -f ".Rprofile",    ".Rprofile created" );
ok( -f "taskfile.yml", "taskfile.yml created" );

# Cleanup happens automatically via tempdir CLEANUP => 1,
# but we should change back to original execution directory first just in case
chdir($original_cwd);

done_testing();
