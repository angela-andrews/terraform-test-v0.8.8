provider "aws"{
    region = "us-east-1"
}
//syntax for resource resource "providerName_typeOfResource" "SomeName"{
//  config      = "value"  
//}
resource "aws_instance" "book_example" {
    ami             = "ami-40d28157"
    instance_type   = "t2.micro"

    tags {
    Name            = "terraform_book-example"
}
}

