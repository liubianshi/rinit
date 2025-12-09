# rinit

A modern R project scaffolding tool written in Perl.

## Features

- 🚀 Quick project initialization with sensible defaults
- 🌍 Multi-language support (English, Chinese)
- 📦 Integrated with renv for dependency management
- 🔧 DVC support for data version control
- 📝 Quarto-ready with customizable templates
- 🎨 Citation styles and Word templates support

## Installation

### Recommended way (via cpanm)

You can install `rinit` easily using `cpanm`. This ensures all dependencies are handled correctly.

```bash
# Install cpanminus if you haven't already
sudo apt-get install cpanminus  # Debian/Ubuntu
# or
curl -L https://cpanmin.us | perl - --sudo App::cpanminus

# Install rinit
git clone https://github.com/yourusername/rinit.git
cd rinit
cpanm .
```

### Manual Installation

If you prefer `make`:

```bash
perl Makefile.PL
make
make test
make install
```

## Usage

```bash
# Create English project (default)
rinit my_analysis

# Create Chinese project
rinit my_analysis zh

# View help
rinit --help
```

## Project Structure

The generated project structure is designed for reproducibility:

```
my_project/
├── raw/                # Raw data (git-ignored, DVC tracked)
├── R/                  # R source code
│   ├── import/        # Data import scripts
│   ├── build/         # Data preparation scripts
│   ├── analysis/      # Analysis scripts
│   ├── check/         # Data validation
│   ├── utils/         # Utility functions
│   └── lib/           # Helper libraries
├── out/               # Generated outputs (git-ignored)
│   ├── data/          # Intermediate data
│   ├── tables/
│   ├── figures/
│   └── manuscript/
├── doc/               # Documentation
├── log/               # Execution logs
├── cache/             # Cached results
├── .pandoc/           # Document templates
│   ├── csl/          # Citation styles
│   └── docx/         # Word templates
├── .Rprofile         # Project R configuration
├── _metadata.yml     # Quarto metadata
└── Snakefile         # Workflow automation
```

## Configuration

### Citation Styles

Place your CSL files in `.pandoc/csl/`. Update `_metadata.yml` to reference them:

```yaml
csl: .pandoc/csl/your-style.csl
```

### Word Templates

Customize your Word output by creating reference documents and placing them in `.pandoc/docx/`.

## Requirements

- Perl 5.10+
- R 4.0+
- Git (optional)
- DVC (optional, for large datasets)

## License

MIT License
