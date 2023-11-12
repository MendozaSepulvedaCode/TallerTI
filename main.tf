terraform {
     required_providers{
        aws = {
            source  = "hashicorp/aws"
            version = "~> 4.16"
        }
    }
    backend "s3" {
        bucket         = "terraformutb"
        key            = "utb/terraform.tfstate"
    }
}

variable "imagebuild" {
  type = string
  description = "the latest image build version"
}


data "aws_availability_zones" "zona_disp" {
  state = "available"
}


resource "aws_ecs_cluster" "cluster_disp" {
  name = "Cluster_Ti" 
}

data "aws_iam_role" "ecsTaskExecutionRole" {
  name = "ecsTaskExecutionRole"
}

resource "aws_ecs_task_definition" "ti_actividad" {
  family                   = "ti_primera" 
  container_definitions    = <<DEFINITION
  [
    {
      "name": "ti_primera",
      "image": "891222389983.dkr.ecr.us-east-2.amazonaws.com/utb:${var.imagebuild}",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 80,
          "hostPort": 80
        }
      ],
      "memory": 512,
      "cpu": 256
    }
  ]
  DEFINITION
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  memory                   = 512
  cpu                      = 256
  execution_role_arn       = data.aws_iam_role.ecsTaskExecutionRole.arn 
}

resource "aws_default_vpc" "default_vpc" {
}

resource "aws_default_subnet" "subnet_disp" {
  availability_zone = "us-east-1a"
}

resource "aws_default_subnet" "disp_sub" {
  availability_zone = "us-east-1b"
}


resource "aws_alb" "app_sub" {
  name               = ""
  load_balancer_type = "application"
  subnets = [
    "${aws_default_subnet.subnet_disp.id}",
    "${aws_default_subnet.disp_sub.id}"
  ]
  # security group
  security_groups = ["${aws_security_group.security_group.id}"]
}

resource "aws_security_group" "security_group" {
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow traffic in from all sources
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_lb_target_group" "ti_grupo" {
  name        = ""
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = "${aws_default_vpc.default_vpc.id}"
}

resource "aws_lb_listener" "esc_ti" {
  load_balancer_arn = "${aws_alb.app_sub.arn}" #  load balancer
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.ti_grupo.arn}" # target group
  }
}


resource "aws_ecs_service" "ecs_service" {
  name            = ""     # Name the service
  cluster         = "${aws_ecs_cluster.cluster_disp.id}"   # Reference the created Cluster
  task_definition = "${aws_ecs_task_definition.ti_actividad.arn}" # Reference the task that the service will spin up
  launch_type     = "FARGATE"
  desired_count   = 3 # Set up the number of containers to 3

  load_balancer {
    target_group_arn = "${aws_lb_target_group.ti_grupo.arn}" # Reference the target group
    container_name   = "${aws_ecs_task_definition.ti_actividad.family}"
    container_port   = 80 # Specify the container port
  }

  network_configuration {
    subnets          = ["${aws_default_subnet.subnet_disp.id}", "${aws_default_subnet.disp_sub.id}"]
    assign_public_ip = true     # Provide the containers with public IPs
    security_groups  = ["${aws_security_group.service_security_group.id}"] # Set up the security group
  }
}

resource "aws_security_group" "service_security_group" {
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    # Only allowing traffic in from the load balancer security group
    security_groups = ["${aws_security_group.security_group.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

output "app_url" {
  value = aws_alb.app_sub.dns_name
}