FROM ubuntu:14.04
                                                                                
# Set corect locale-related environment variables                               
ENV LANG="en_US.UTF-8" LANGUAGE="en_US:en" LC_ALL="en_US.UTF-8"                 
RUN locale-gen $LANG && \
    update-locale LANG=$LANG && \
    update-locale LANGUAGE=$LANGUAGE  

# Install system deps (used to speed-up tests
# avoiding install of some system  packages)
RUN apt-get update -qq && apt-get upgrade -qq -y && \
    apt-get install -y -qq gnupg2 curl wget git && \
    rm -rf /var/lib/apt/lists/*

# Add user odoo
RUN adduser --home=/home/odoo odoo && \
    echo "odoo ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/odoo

USER odoo
WORKDIR /home/odoo

# Install RVM
RUN gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 && \
    curl -sSL https://get.rvm.io | bash -s stable --ruby

# Install ruby
RUN bash -c 'source /home/odoo/.rvm/scripts/rvm; rvm install ruby-2.3; rvm use 2.3'

# Install test coverage deps
RUN bash -c 'source /home/odoo/.rvm/scripts/rvm; gem install bashcov coveralls'

# Create empty /home/odoo/bin dir, to make odoo-helper user-install work
RUN mkdir /home/odoo/bin
