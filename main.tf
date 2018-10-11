provider "aws"{
    region = "us-east-1"
}
//syntax for resource resource "providerName_typeOfResource" "SomeName"{
//  config      = "value"  
//}
resource "aws_launch_configuration" "book_example" {
    // ami             = "ami-40d28157" <- for single instance
    image_id        = "ami-40d28157"
    instance_type   = "t2.micro"
    // vpc_security_group_ids =["${aws_security_group.instance.id}"] <- for single instance
    security_groups  =["${aws_security_group.instance.id}"]

    user_data = <<-EOF
                #!/bin/bash
                echo "Hello, all! Tonight is codeNewbie night" > index.html
                nohup busybox httpd -f -p "${var.server_port}" &
                EOF
    //lifecycle goes on on every resourse that this resource depends on (launch_cgf & sec_group)
    lifecycle {
        create_before_destroy = true
    }
    // tag {
    // Name            = "book_example"
    // }
}
//---------  security groups 
//to allow incoming or outgoing traffic to the instance, you need a security group and assign it to the instance above
resource "aws_security_group" "instance" {
    name = "terraform-book_example-instance"

    ingress {
        //use interpolation for repeated values "${var.SOMEVAR}"
        from_port       = "${var.server_port}"
        to_port         = "${var.server_port}"
        protocol        = "tcp"
        cidr_blocks     = ["0.0.0.0/0"]   
    }
    
    lifecycle {
        create_before_destroy = true
    }
}
resource "aws_security_group" "elb" {
    name = "book_example_elb"
    //incoming requests to elb
    ingress {
        from_port = 80
        to_port = 80
        protocol= "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    //to allow health checks, must set outbound traffic
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1" 
        cidr_blocks = ["0.0.0.0/0"]
    }
}
//---------end security groups

// this may have been my issue in v0.11.8  {mising} this data source
//fetches the AZs specifiy to my account
data "aws_availability_zones" "all" {}



resource "aws_autoscaling_group" "book_example" {
  launch_configuration = "${aws_launch_configuration.book_example.id}"
  availability_zones   = ["${data.aws_availability_zones.all.names}"]
        //this was problematic in v0.11.8 ^ 
  load_balancers    = ["${aws_elb.book_example_elb.name}"]
  health_check_type = "ELB"

  min_size = 2
  max_size = 10

  tag {
    key                 = "Name"
    value               = "terraform-asg-example"
    propagate_at_launch = true
  }
}

//---ELB code that sets up requests to come in on port 80 & 
//route them to the instances in ASG------

resource "aws_elb" "book_example_elb"{
    name            = "terraform-asg-example"
    availability_zones = ["${data.aws_availability_zones.all.names}"]
    security_groups = ["${aws_security_group.elb.id}"]
    
    listener {
        lb_port          =80
        lb_protocol     = "http"
        instance_port = "${var.server_port}"
        instance_protocol = "http"
    }

    health_check {
        healthy_threshold = 2
        unhealthy_threshold = 2
        timeout = 3
        interval = 30
        target = "HTTP:${var.server_port}/"
    }
}

//--------------variables-----------------
variable  "server_port" {
    description         = "Port used for https reqests"
    default             = 8080
}


//--------outputs: so you don't have to dig or guess------
//to see outputs: > terraform output
output "elb_dns_name" {
    value = "${aws_elb.book_example_elb.dns_name}"
}