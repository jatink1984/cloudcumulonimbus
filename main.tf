provider "aws" {
  region  = "${var.aws_region}"
  profile = "${var.aws_profile}"
}

#----- IAM -----

#S3_access

resource "aws_iam_instance_profile" "s3_access_profile" {
  name = "s3_access"
  role = "${aws_iam_role.s3_access_role.name}"
}

resource "aws_iam_role_policy" "s3_access_policy" {
  name = "s3_access_policy"
  role = "${aws_iam_role.s3_access_role.id}"

  policy = <<HEREDOC
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "s3:*"
        ],
        "Effect": "Allow",
        "Resource": "*"
      }
    ]
}
  HEREDOC
}

resource "aws_iam_role" "s3_access_role" {
  name = "s3_access_role"

  assume_role_policy = <<HEREDOC
{
    "Version": "2012-10-17",
    "Statement" : [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "ec2.amazonaws.com"
     },
      "Effect": "Allow",
      "Sid": ""
      }
    ]
}
  HEREDOC
}

#-----VPC-----

resource "aws_vpc" "wp_vpc" {
  cidr_block           = "${var.vpc_cidr}"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags {
    Name = "wp_vpc"
  }
}

#-----IGW-----

resource "aws_internet_gateway" "wp_internet_gateway" {
  vpc_id = "${aws_vpc.wp_vpc.id}"

  tags {
    Name = "wp_igw"
  }
}

#-----Route Tables-----
#public route table
resource "aws_route_table" "wp_public_rt" {
  vpc_id = "${aws_vpc.wp_vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.wp_internet_gateway.id}"
  }

  tags {
    Name = "wp_public"
  }
}

#Private route table
resource "aws_default_route_table" "wp_private_rt" {
  default_route_table_id = "${aws_vpc.wp_vpc.default_route_table_id}"

  tags {
    Name = "wp_private"
  }
}

#------Subnets-----

resource "aws_subnet" "wp_public1_subnet" {
  vpc_id                  = "${aws_vpc.wp_vpc.id}"
  cidr_block              = "${var.cidrs["public1"]}"
  map_public_ip_on_launch = true
  availability_zone       = "${data.aws_availability_zones.available.names[0]}"

  tags {
    Name = "wp_public1"
  }
}

resource "aws_subnet" "wp_public2_subnet" {
  vpc_id                  = "${aws_vpc.wp_vpc.id}"
  cidr_block              = "${var.cidrs["public2"]}"
  map_public_ip_on_launch = true
  availability_zone       = "${data.aws_availability_zones.available.names[1]}"

  tags {
    Name = "wp_public2"
  }
}

#----Private subnet application layer----
resource "aws_subnet" "wp_private1_subnet" {
  vpc_id                  = "${aws_vpc.wp_vpc.id}"
  cidr_block              = "${var.cidrs["private1"]}"
  map_public_ip_on_launch = false
  availability_zone       = "${data.aws_availability_zones.available.names[0]}"

  tags {
    Name = "wp_private1"
  }
}

resource "aws_subnet" "wp_private2_subnet" {
  vpc_id                  = "${aws_vpc.wp_vpc.id}"
  cidr_block              = "${var.cidrs["private2"]}"
  map_public_ip_on_launch = false
  availability_zone       = "${data.aws_availability_zones.available.names[1]}"

  tags {
    Name = "wp_private2"
  }
}

#-----RDS Subnets------
resource "aws_subnet" "wp_rds1_subnet" {
  vpc_id                  = "${aws_vpc.wp_vpc.id}"
  cidr_block              = "${var.cidrs["rds1"]}"
  map_public_ip_on_launch = false
  availability_zone       = "${data.aws_availability_zones.available.names[0]}"

  tags {
    Name = "wp_rds1"
  }
}

resource "aws_subnet" "wp_rds2_subnet" {
  vpc_id                  = "${aws_vpc.wp_vpc.id}"
  cidr_block              = "${var.cidrs["rds2"]}"
  map_public_ip_on_launch = false
  availability_zone       = "${data.aws_availability_zones.available.names[1]}"

  tags {
    Name = "wp_rds2"
  }
}

resource "aws_subnet" "wp_rds3_subnet" {
  vpc_id                  = "${aws_vpc.wp_vpc.id}"
  cidr_block              = "${var.cidrs["rds3"]}"
  map_public_ip_on_launch = false
  availability_zone       = "${data.aws_availability_zones.available.names[2]}"

  tags {
    Name = "wp_rds3"
  }
}

#-----Private subnet group for RDS

resource "aws_db_subnet_group" "wp_rds_subnetgroup" {
  name = "wp_rds_subnetgroup"

  subnet_ids = ["${aws_subnet.wp_rds1_subnet.id}", "${aws_subnet.wp_rds2_subnet.id}", "${aws_subnet.wp_rds3_subnet.id}"]

  tags {
    Name = "wp_rds_sng"
  }
}

#-----Subnet Associations----

resource "aws_route_table_association" "wp_public1_assoc" {
  subnet_id      = "${aws_subnet.wp_public1_subnet.id}"
  route_table_id = "${aws_route_table.wp_public_rt.id}"
}

resource "aws_route_table_association" "wp_public2_assoc" {
  subnet_id      = "${aws_subnet.wp_public2_subnet.id}"
  route_table_id = "${aws_route_table.wp_public_rt.id}"
}

resource "aws_route_table_association" "wp_private1_assoc" {
  subnet_id      = "${aws_subnet.wp_private1_subnet.id}"
  route_table_id = "${aws_default_route_table.wp_private_rt.id}"
}

resource "aws_route_table_association" "wp_private2_assoc" {
  subnet_id      = "${aws_subnet.wp_private2_subnet.id}"
  route_table_id = "${aws_default_route_table.wp_private_rt.id}"
}

#-----Security Groups-----

resource "aws_security_group" "wp_dev_sg" {
  name        = "wp_dev_sg"
  description = "Used to access the dev instance"
  vpc_id      = "${aws_vpc.wp_vpc.id}"

  #SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.localip}"]
  }

  #HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#----Public Security Group-----
resource "aws_security_group" "wp_public_sg" {
  name        = "wp_public_sg"
  description = "Used to allow public access to load balanceer"
  vpc_id      = "${aws_vpc.wp_vpc.id}"

  #HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#----Private Security Group----
resource "aws_security_group" "wp_private_sg" {
  name        = "wp_private_sg"
  description = "Used for private instances"
  vpc_id      = "${aws_vpc.wp_vpc.id}"

  #Access from VPC

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${var.vpc_cidr}"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#-----RDS Security Group-----
resource "aws_security_group" "wp_rds_sg" {
  name        = "wp_rds_sg"
  description = "Used for RDS instances"
  vpc_id      = "${aws_vpc.wp_vpc.id}"

  # SQL access from public/private security groups
  ingress {
    from_port = "3306"
    to_port   = "3306"
    protocol  = "tcp"

    security_groups = ["${aws_security_group.wp_dev_sg.id}",
      "${aws_security_group.wp_private_sg.id}",
      "${aws_security_group.wp_public_sg.id}",
    ]
  }
}

#-----VPC Endpoint for S3-----
resource "aws_vpc_endpoint" "wp_private-s3_endpoint" {
  vpc_id       = "${aws_vpc.wp_vpc.id}"
  service_name = "com.amazonaws.${var.aws_region}.s3"

  route_table_ids = ["${aws_vpc.wp_vpc.main_route_table_id}", "${aws_route_table.wp_public_rt.id}"]

  policy = <<POLICY
  {
    "Statement": [
      {
        "Action": "*",
        "Effect": "Allow",
        "Resource": "*",
        "Principal": "*"
      }
    ]
  }
  POLICY
}

#------S3 Bucket-----
resource "random_id" "wp_code_bucket" {
  byte_length = 2
}

resource "aws_s3_bucket" "code" {
  bucket        = "${var.domain_name}-${random_id.wp_code_bucket.dec}"
  acl           = "private"
  force_destroy = true

  tags {
    Name = "code bucket"
  }
}

#------RDS Instances-----
resource "aws_db_instance" "wp_db" {
  allocated_storage      = 10
  engine                 = "mysql"
  engine_version         = "5.6.41"
  instance_class         = "${var.db_instance_class}"
  name                   = "${var.dbname}"
  username               = "${var.dbuser}"
  password               = "${var.dbpassword}"
  db_subnet_group_name   = "${aws_db_subnet_group.wp_rds_subnetgroup.name}"
  vpc_security_group_ids = ["${aws_security_group.wp_rds_sg.id}"]
  skip_final_snapshot    = true
}

#-----DEV SERVER-----

# key pair
resource "aws_key_pair" "wp_auth" {
  key_name   = "${var.key_name}"
  public_key = "${file(var.public_key_path)}"
}

resource "aws_instance" "wp_dev" {
  instance_type = "${var.dev_instance_type}"
  ami           = "${var.dev_ami}"

  tags {
    Name = "wp_dev"
  }

  key_name               = "${aws_key_pair.wp_auth.id}"
  vpc_security_group_ids = ["${aws_security_group.wp_dev_sg.id}"]
  iam_instance_profile   = "${aws_iam_instance_profile.s3_access_profile.id}"
  subnet_id              = "${aws_subnet.wp_public1_subnet.id}"

  provisioner "local-exec" {
    command = <<EOD
cat <<EOF > aws_hosts
[dev]
"ec2-user@${aws_instance.wp_dev.public_ip}"
[dev:vars]
s3code=${aws_s3_bucket.code.bucket}
domain=${var.domain_name}
EOF
EOD
  }

  provisioner "local-exec" {
    command = "aws ec2 wait instance-status-ok --instance-ids ${aws_instance.wp_dev.id} --profile superhero && ansible-playbook -i aws_hosts wordpress.yml"
  }
}

#-----Load Balancer-----
/*
resource "aws_elb" "wp_elb" {
  name = "${var.domain_name}-elb"

  subnets = ["${aws_subnet.wp_public1_subnet.id}", "${aws_subnet.wp_public2_subnet.id}"]
  security_groups = ["${aws_security_group.wp_public_sg.id}"]
  listener {
    instance_port = 80
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
  }

  health_check {
    healthy_threshold = "${var.elb_healthy_threshold}"
    unhealthy_threshold = "${var.elb_unhealthy_threshold}"
    timeout = "${var.elb_timeout}"
    target = "TCP:80"
    interval = "${var.elb_interval}"
  }

  cross_zone_load_balancing = true
  idle_timeout = 400
  connection_draining = true
  connection_draining_timeout = 400

  tags {
    Name = "wp_${var.domain_name}-elb"
  }
}
*/
#------- Create ALB ------
resource "aws_lb" "wp_alb" {
  name                             = "${var.domain_name}-alb"
  subnets                          = ["${aws_subnet.wp_public1_subnet.id}", "${aws_subnet.wp_public2_subnet.id}"]
  security_groups                  = ["${aws_security_group.wp_public_sg.id}"]
  internal                         = false
  load_balancer_type               = "application"
  enable_deletion_protection       = false
  idle_timeout                     = 400
  enable_cross_zone_load_balancing = true

  tags {
    Name = "wp_${var.domain_name}-alb"
  }
}

resource "aws_lb_listener" "wp_listner" {
  load_balancer_arn = "${aws_lb.wp_alb.arn}"
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.wp_tg.arn}"
  }
}

resource "aws_alb_listener_rule" "wp_http_forward" {
  depends_on   = ["aws_lb_target_group.wp_tg"]
  listener_arn = "${aws_lb_listener.wp_listner.arn}"

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.wp_tg.arn}"
  }

  condition {
    host_header {
      values = ["*.cloudcumulonimbus.com"]
    }
  }
}

resource "aws_lb_target_group" "wp_tg" {
  name     = "${var.target_group_name}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.wp_vpc.id}"

  tags {
    name = "${var.target_group_name}"
  }

  health_check {
    healthy_threshold   = "${var.elb_healthy_threshold}"
    unhealthy_threshold = "${var.elb_unhealthy_threshold}"
    timeout             = "${var.elb_timeout}"
    interval            = 20
    path                = "/"
    port                = 80
  }
}

resource "aws_autoscaling_attachment" "wp_asg_attachment" {
  autoscaling_group_name = "${aws_autoscaling_group.wp_asg.id}"
  alb_target_group_arn   = "${aws_lb_target_group.wp_tg.arn}"
}

#----- AMI for autoscaling group ----
resource "random_id" "golden_ami" {
  byte_length = 3
}

resource "aws_ami_from_instance" "wp_golden" {
  name               = "wp_ami-${random_id.golden_ami.b64}"
  source_instance_id = "${aws_instance.wp_dev.id}"

  provisioner "local-exec" {
    command = <<EOT
    cat <<EOF > userdata
    #!/bin/bash
    /usr/bin/aws s3 sync s3://${aws_s3_bucket.code.bucket} /var/www/html/
    /bin/touch /var/spool/cron/root
    sudo /bin/echo '*/5 * * * * aws s3 sync s3://${aws_s3_bucket.code.bucket} /var/www/html' >> /var/spool/cron/root
    EOF
    EOT
  }
}

#----- Launch Configuration ------
resource "aws_launch_configuration" "wp_lc" {
  name_prefix          = "wp_lc-"
  image_id             = "${aws_ami_from_instance.wp_golden.id}"
  instance_type        = "${var.lc_instance_type}"
  security_groups      = ["${aws_security_group.wp_private_sg.id}"]
  iam_instance_profile = "${aws_iam_instance_profile.s3_access_profile.id}"
  key_name             = "${aws_key_pair.wp_auth.id}"
  user_data            = "${file("userdata")}"

  lifecycle {
    create_before_destroy = true
  }
}

#------- ASG ------
resource "aws_autoscaling_group" "wp_asg" {
  name                      = "asg-${aws_launch_configuration.wp_lc.id}"
  max_size                  = "${var.asg_max}"
  min_size                  = "${var.asg_min}"
  health_check_grace_period = "${var.asg_grace}"
  health_check_type         = "${var.asg_hct}"
  desired_capacity          = "${var.asg_cap}"
  force_delete              = true
  target_group_arns         = ["${aws_lb_target_group.wp_tg.arn}"]

  # load_balancers = ["${aws_lb.wp_alb.id}"]
  vpc_zone_identifier  = ["${aws_subnet.wp_private1_subnet.id}", "${aws_subnet.wp_private2_subnet.id}"]
  launch_configuration = "${aws_launch_configuration.wp_lc.name}"

  tag {
    key                 = "Name"
    value               = "wp_asg-instance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

#-----Route53 resources -----

#primary zone

resource "aws_route53_zone" "primary" {
  name              = "${var.domain_name}.com"
  delegation_set_id = "${var.delegation_set}"
}

#WWW Record
resource "aws_route53_record" "www" {
  name    = "www.${var.domain_name}.com"
  zone_id = "${aws_route53_zone.primary.zone_id}"
  type    = "A"

  alias {
    name                   = "${aws_lb.wp_alb.dns_name}"
    zone_id                = "${aws_lb.wp_alb.zone_id}"
    evaluate_target_health = false
  }
}

#DEV

resource "aws_route53_record" "dev" {
  name    = "dev.${var.domain_name}.com"
  zone_id = "${aws_route53_zone.primary.zone_id}"
  type    = "A"
  ttl     = "300"
  records = ["${aws_instance.wp_dev.public_ip}"]
}

#Private Zone

resource "aws_route53_zone" "secondary" {
  name = "${var.domain_name}.com"

  vpc {
    vpc_id = "${aws_vpc.wp_vpc.id}"
  }
}

#DB Record
resource "aws_route53_record" "db" {
  name    = "db.${var.domain_name}.com"
  zone_id = "${aws_route53_zone.secondary.zone_id}"
  type    = "CNAME"
  ttl     = "300"
  records = ["${aws_db_instance.wp_db.address}"]
}
