locals {
  # We use a heredoc template here
  ec2_user_data = <<-EOF
    #!/bin/bash
    # 1. Install Fluent Bit
    sudo amazon-linux-extras install -y epel
    curl https://raw.githubusercontent.com/fluent/fluent-bit/master/install.sh | sh
    
    # 2. Create config directory
    mkdir -p /etc/fluent-bit/
    mkdir -p /var/log/fluent-bit/buffer

    # 3. Write the Fluent Bit Config
    cat <<EOC > /etc/fluent-bit/fluent-bit.conf
    [SERVICE]
        Flush        1
        Daemon       Off
        Log_Level    info
        storage.path /var/log/fluent-bit/buffer
        storage.sync normal
        storage.checksum off
        storage.backlog.mem_limit 50M

    [INPUT]
        Name         tail
        Path         /var/log/nginx/access.log
        Tag          nginx.access
        Parser       nginx
        storage.type filesystem

    [INPUT]
        Name         systemd
        Tag          systemd.logs
        Systemd_Filter _SYSTEMD_UNIT=sshd.service

    [FILTER]
        Name         modify
        Match        *
        Add          hostname $(hostname)
        Add          env production

    [OUTPUT]
        Name         loki
        Match        *
        Host         loki-internal.ematiq.com
        Port         3100
        Labels       job=ec2-logs, instance=$(hostname)
        Line_Format  json
        Remove_Keys  hostname
    EOC

    # 4. Enable and Start the service
    systemctl enable fluent-bit
    systemctl start fluent-bit
  EOF
}

resource "aws_instance" "example_ec2" {
  ami                  = "ami-0c55b159cbfafe1f0"
  instance_type        = "t3.medium"
  iam_instance_profile = aws_iam_instance_profile.ec2_logging_role.name

  user_data = local.ec2_user_data

  tags = {
    Name = "Web-Server-Logging"
  }
}