FROM amazon/aws-cli:2.14.2

COPY delete.sh /delete.sh

# Get tools needed (jq)
RUN yum install -y jq && \
    yum clean all && \
    rm -rf /var/cache/yum
