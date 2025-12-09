package RInit::Templates;

use strict;
use warnings;
sub get_project_files {
  my ( $class, $project_name, $lang ) = @_;

  require RInit::Manifest;
  my $files = RInit::Manifest->get_files( $project_name, $lang );
  my @operations;

  for my $file (@$files) {
    die "Source file path missing for target '$file->{target}'" unless $file->{source};

    # If processing is needed, read content
    if ( $file->{process} ) {
      open my $fh, '<', $file->{source} or die "Cannot read source '$file->{source}': $!";
      local $/;
      my $content = <$fh>;
      close $fh;

      $content = $file->{process}->($content);

      push @operations, { target => $file->{target}, content => $content };
    }
    else {
      # No processing needed, use direct copy
      push @operations, { target => $file->{target}, source => $file->{source} };
    }
  }

  return \@operations;
}

1;
