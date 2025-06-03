#!/bin/bash
# Add Jenkins user to docker group
sudo usermod -aG docker jenkins

# Restart Jenkins service
sudo systemctl restart jenkins

# Verify docker permissions
echo "Verifying Docker socket permissions:"
ls -la /var/run/docker.sock

echo "Script complete. Jenkins will restart."
echo "You may need to reconnect to Jenkins after a few moments."
