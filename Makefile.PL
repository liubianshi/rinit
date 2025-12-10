use ExtUtils::MakeMaker;

# Stub install_share since we handle it manually in postamble
*install_share = sub {};

install_share('share');

package MY;
use strict;
use warnings;

# Force manual postamble to ensure dotfiles (.pandoc) are installed
sub postamble {
    my $share_src = 'share';
    
    return <<"MAKE_FRAG";
install ::
\t\$(NOECHO) \$(ECHO) "Manually installing share directory..."
\tID=\$\$(id -u); \\
\tif [ "\$\$ID" -eq 0 ] && [ -n "\$\$SUDO_USER" ]; then \\
\t\tUSER_HOME=\$\$(eval echo ~\$\$SUDO_USER); \\
\telse \\
\t\tUSER_HOME=\$(HOME); \\
\tfi; \\
\tSHARE_DIR="\$\${XDG_DATA_HOME:-\$\$USER_HOME/.local/share}/Rinit"; \\
\t\$(MKPATH) "\$\$SHARE_DIR"; \\
\t\$(CP) -rf $share_src/. "\$\$SHARE_DIR/"; \\
\t\$(ECHO) "Share directory installed to \$\$SHARE_DIR"; \\
\t\$(CHMOD) -R u+w "\$\$SHARE_DIR"

MAKE_FRAG
}
package main;



WriteMakefile(
    NAME             => 'RInit',
    VERSION_FROM     => 'lib/RInit/App.pm',
    ABSTRACT         => 'A modern R project scaffolding tool written in Perl.',
    AUTHOR           => 'Your Name <your.email@example.com>',
    EXE_FILES        => ['bin/rinit'],
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => 0,
    },
    PREREQ_PM        => {
        'File::Path' => 0,
        'File::Basename' => 0,
        'File::Spec' => 0,
        'Cwd' => 0,
        'Getopt::Long' => 0,
        'Term::ANSIColor' => 0,
        'Pod::Usage' => 0,
    },
    test             => { TESTS => 't/*.t' },
);


