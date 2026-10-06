FROM rocker/r-ver:4.3.2

# System libraries needed by the R dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

# Install dependencies first (cached layer), then the package itself
COPY DESCRIPTION ./
RUN R -e "install.packages('remotes', repos = 'https://cloud.r-project.org'); \
          remotes::install_deps('.', dependencies = NA, repos = 'https://cloud.r-project.org')"

COPY . .
RUN R CMD INSTALL --no-docs --no-multiarch . && rm -rf /src

EXPOSE 43210

CMD ["R", "-e", "dsiStudio::run_app(port = 43210, host = '0.0.0.0')"]
