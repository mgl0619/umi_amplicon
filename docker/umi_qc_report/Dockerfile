FROM python:3.11-slim

# Copy corporate root certificate
COPY ./ca-certificates.crt /etc/ssl/certs/

# Set environment variable so python trusts it
ENV REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt

#RUN update-ca-certificates
ARG PIP_TRUSTED_HOST=files.pythonhosted.org pypi.org
ENV PIP_TRUSTED_HOST=${PIP_TRUSTED_HOST}

# Install required Python packages
RUN pip install --no-cache-dir \
    plotly==5.18.0 \
    numpy==1.24.3 \
    pandas==2.0.3

RUN apt-get update && apt-get install -y --no-install-recommends procps && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Default command
CMD ["/bin/bash"]
