# Use an official Perl runtime as a base image
FROM perl:latest

# Set the working directory to /app
WORKDIR /project-renard/devops

# Copy setup-docker-curie.sh
# COPY setup-docker-curie.sh /setup-curie.sh

# Copy the current directory contents into the container at /app
ADD . /project-renard/devops

# Install any needed packages specified in requirements.txt
# RUN pip install -r requirements.txt

# Make port 80 available to the world outside this container
# EXPOSE 80

# Define environment variable
# ENV NAME World

RUN apt-get update -y
RUN apt-get install -y sudo
RUN apt-get install -y git
RUN git clone https://github.com/project-renard/devops.git ~/project-renard/devops
RUN git clone https://github.com/project-renard/curie.git  ~/project-renard/curie
RUN git clone https://github.com/project-renard/test-data.git  ~/project-renard/test-data
RUN /project-renard/devops/script/from-vagrant/os-install-debian || true
RUN /project-renard/devops/script/from-vagrant/cpan-setup

CMD ["echo","Setting up currie"]

# Run setup-curie.sh when the container launches
CMD ["/project-renard/devops/docker/docker-repository/setup-docker-curie.sh"]
