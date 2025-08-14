#!/bin/bash
set -e

# Color variables
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pause() { sleep 2; }

echo -e "${YELLOW}=== Detecting OS ===${NC}"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_NAME=$(echo "$ID" | tr '[:upper:]' '[:lower:]')
    OS_VER=$VERSION_ID
    echo -e "${GREEN}Detected OS: $OS_NAME $OS_VER${NC}"
else
    echo -e "${YELLOW}Unsupported OS. Exiting.${NC}"
    exit 1
fi

echo -e "${YELLOW}=== Updating system ===${NC}"
if [[ "$OS_NAME" == "amzn" ]]; then
    sudo dnf update -y
    sudo dnf install -y wget unzip git net-tools firewalld
elif [[ "$OS_NAME" == "rhel" || "$OS_NAME" == "centos" || "$OS_NAME" == "rocky" ]]; then
    sudo dnf update -y
    sudo dnf install -y wget unzip git net-tools firewalld
else
    echo -e "${YELLOW}Unsupported OS for automatic setup. Exiting.${NC}"
    exit 1
fi
pause

echo -e "${YELLOW}=== Enabling and starting firewalld ===${NC}"
sudo systemctl enable --now firewalld
pause

echo -e "${YELLOW}=== Removing Podman to avoid Docker conflict ===${NC}"
sudo dnf remove -y podman podman-docker buildah || true
pause

echo -e "${YELLOW}=== Installing Java 17 ===${NC}"
if [[ "$OS_NAME" == "amzn" ]]; then
    sudo dnf install -y java-17-amazon-corretto java-17-amazon-corretto-devel
elif [[ "$OS_NAME" == "rhel" || "$OS_NAME" == "centos" || "$OS_NAME" == "rocky" ]]; then
    sudo dnf install -y java-17-openjdk java-17-openjdk-devel
fi

JAVA_BIN=$(which java || true)
if [ -z "$JAVA_BIN" ]; then
    echo -e "${YELLOW}ERROR: Java binary not found! Exiting.${NC}"
    exit 1
fi

echo -e "${GREEN}Java installed successfully:${NC}"
java -version
pause

echo -e "${YELLOW}=== Adding Jenkins repo & installing Jenkins ===${NC}"
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
sudo dnf install -y jenkins || true
pause

if [ -f /etc/sysconfig/jenkins ]; then
    sudo sed -i 's|^JENKINS_LISTEN_ADDRESS=.*|JENKINS_LISTEN_ADDRESS="0.0.0.0"|' /etc/sysconfig/jenkins
else
    echo -e "${YELLOW}WARNING: Jenkins config file not found, skipping listen address change.${NC}"
fi

echo -e "${YELLOW}=== Opening firewall for Jenkins (8080) and SonarQube (9000) ===${NC}"
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --permanent --add-port=9000/tcp
sudo firewall-cmd --reload
pause

echo -e "${YELLOW}=== Starting & enabling Jenkins ===${NC}"
sudo systemctl daemon-reexec
sudo systemctl enable --now jenkins
pause

echo -e "${YELLOW}=== Installing Docker ===${NC}"
if [[ "$OS_NAME" == "amzn" ]]; then
    sudo dnf install -y docker
elif [[ "$OS_NAME" == "rhel" || "$OS_NAME" == "centos" || "$OS_NAME" == "rocky" ]]; then
    sudo dnf install -y dnf-plugins-core || true
    sudo dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo || true
    sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || \
        sudo dnf install -y docker
fi

sudo systemctl enable --now docker
sudo usermod -aG docker $USER
sudo usermod -aG docker jenkins
docker --version
pause

echo -e "${YELLOW}=== Installing Maven ===${NC}"
sudo dnf install -y maven
mvn -v
pause

echo -e "${YELLOW}=== Installing AWS CLI v2 ===${NC}"
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip -q awscliv2.zip
sudo ./aws/install
aws --version
rm -rf aws awscliv2.zip
pause

echo -e "${YELLOW}=== Installing kubectl ===${NC}"
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client
pause

echo -e "${YELLOW}=== Installing eksctl ===${NC}"
curl --silent --location \
"https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" \
| tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
eksctl version
pause

echo -e "${YELLOW}=== Running SonarQube in Docker ===${NC}"
docker rm -f sonar >/dev/null 2>&1 || true
docker run -dit --name sonar \
    -p 9000:9000 \
    -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true \
    sonarqube:latest
pause

VM_IP=$(hostname -I | awk '{print $1}')
echo -e "${GREEN}=== Setup complete! ===${NC}"
echo -e "${GREEN}Jenkins:   http://$VM_IP:8080${NC}"
echo -e "${GREEN}SonarQube: http://$VM_IP:9000${NC}"
echo -e "${GREEN}Get Jenkins admin password with: sudo cat /var/lib/jenkins/secrets/initialAdminPassword${NC}"

