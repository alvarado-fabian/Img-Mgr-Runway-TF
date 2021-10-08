output "vpc_id" {
  description = "ID of project VPC"
  value = aws_vpc.common-vpc.id
}

output "public_subnets" {
  description = "List of public subnets"
  value = [ aws_subnet.common-subnet-public-1.id, aws_subnet.common-subnet-public-2.id ]
}

output "private_subnets" {
  description = "List of private subnets"
  value = [ aws_subnet.common-subnet-private-1.id, aws_subnet.common-subnet-private-2.id ]
}

output "public_subnets_Azs" {
  description = "List of Azs"
  value = [ aws_subnet.common-subnet-public-1.availability_zone, aws_subnet.common-subnet-public-2.availability_zone ]
}
