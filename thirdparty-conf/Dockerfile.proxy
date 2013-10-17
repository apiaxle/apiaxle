FROM centos:6.4

# Enable EPEL for Node.js
RUN rpm -Uvh http://download.fedoraproject.org/pub/epel/6/i386/epel-release-6-8.noarch.rpm

# Install Node.js and npm
RUN yum install -y npm make gcc libxml2-devel redis git

RUN npm install -g apiaxle-repl apiaxle-api apiaxle-proxy || cat npm-debug.log

EXPOSE 3000

CMD [ "sh", "-c", "/etc/init.d/redis start; apiaxle-proxy -f 1 -h 0.0.0.0 -p 3000" ]
