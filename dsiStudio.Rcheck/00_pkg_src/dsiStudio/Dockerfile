FROM rocker/r-ver:4.3.2

# Install system dependencies
RUN apt-get update && apt-get install -y \
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

# Set working directory
WORKDIR /app

# Copy package files
COPY DESCRIPTION .
COPY LICENSE .

# Install R package dependencies
RUN R -e "install.packages(c( \
    'shiny', \
    'bslib', \
    'dplyr', \
    'tidyr', \
    'ggplot2', \
    'readr', \
    'readxl', \
    'DT', \
    'digest', \
    'gridExtra', \
    'yaml', \
    'jsonlite', \
    'testthat' \
  ), repos='https://cloud.r-project.org/')"

# Copy application files
COPY app.R .
COPY R/ ./R/
COPY inst/ ./inst/
COPY tests/ ./tests/

# Expose port
EXPOSE 43210

# Run app
CMD ["R", "-e", "shiny::runApp('.', port=43210, host='0.0.0.0')"]
