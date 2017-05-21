# Use an official Perl runtime as a base image
FROM perl:latest

# Set the working directory to /app
WORKDIR /project-renard

# Copy setup-docker-curie.sh
# COPY setup-docker-curie.sh /setup-curie.sh

# Copy the current directory contents into the container at /app
ADD . /project-renard

# Install any needed packages specified in requirements.txt
# RUN pip install -r requirements.txt

# Make port 80 available to the world outside this container
# EXPOSE 80

# Define environment variable
# ENV NAME World

CMD ["echo","Setting up currie"]

# Run setup-curie.sh when the container launches
CMD ["setup-docker-curie.sh"]
