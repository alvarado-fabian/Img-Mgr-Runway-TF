# Backend setup
terraform {
  backend "s3" {
    key = "common-vpc.tfstate"
  }
}
# Variable definitions
variable "region" {}

# Provider and access setup
provider "aws" {
  version = "~> 2.0"
  region = "${var.region}"
}

# Data and resources

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_eip" "nat1" {
  vpc = true
}
resource "aws_eip" "nat2" {
  vpc = true
}

## VPC creation

resource "aws_vpc" "common-vpc" {
    cidr_block = "10.0.0.0/16"
    enable_dns_support = "true" #gives you an internal domain name
    enable_dns_hostnames = "true" #gives you an internal host name
    enable_classiclink = "false"
    instance_tenancy = "default"

    tags = {
      Name = "common_vpc"
    }
}

## Public and Private Subnets

resource "aws_subnet" "common-subnet-public-1" {
    vpc_id = aws_vpc.common-vpc.id
    cidr_block = "10.0.1.0/24"
    map_public_ip_on_launch = "true" //it makes this a public subnet
    availability_zone = data.aws_availability_zones.available.names[0]

    tags = {
        Name = "common-subnets-public"
    }
}

resource "aws_subnet" "common-subnet-public-2" {
    vpc_id = aws_vpc.common-vpc.id
    cidr_block = "10.0.2.0/24"
    map_public_ip_on_launch = "true" //it makes this a public subnet
    availability_zone = data.aws_availability_zones.available.names[1]

    tags = {
        Name = "common-subnets-public"
    }
}

resource "aws_subnet" "common-subnet-private-1" {
    vpc_id = aws_vpc.common-vpc.id
    cidr_block = "10.0.3.0/24"
    map_public_ip_on_launch = "false" //it makes this a public subnet
    availability_zone = data.aws_availability_zones.available.names[0]

    tags = {
        Name = "common-subnets-private"
    }
}

resource "aws_subnet" "common-subnet-private-2" {
    vpc_id = aws_vpc.common-vpc.id
    cidr_block = "10.0.4.0/24"
    map_public_ip_on_launch = "false" //it makes this a public subnet
    availability_zone = data.aws_availability_zones.available.names[1]

    tags = {
        Name = "common-subnets-private"
    }
}

## Internet Gateway for VPC

resource "aws_internet_gateway" "common-igw" {
    vpc_id = aws_vpc.common-vpc.id
    tags = {
        Name = "common-igw"
    }
}

##  Public Route Table

resource "aws_route_table" "common-public-route-table" {
    vpc_id = aws_vpc.common-vpc.id

    route {
        //associated subnet can reach everywhere
        cidr_block = "0.0.0.0/0"         //CRT uses this IGW to reach internet
        gateway_id = aws_internet_gateway.common-igw.id
    }

    tags = {
        Name = "common-public-route-table"
    }
}

##  Public Route Table Associations

resource "aws_route_table_association" "common-crta-public-subnet-1"{
    subnet_id = aws_subnet.common-subnet-public-1.id
    route_table_id = aws_route_table.common-public-route-table.id
}
resource "aws_route_table_association" "common-crta-public-subnet-2"{
    subnet_id = aws_subnet.common-subnet-public-2.id
    route_table_id = aws_route_table.common-public-route-table.id
}

##  NAT Gateway creation

resource "aws_nat_gateway" "nat-gw-a" {
  allocation_id = aws_eip.nat1.id
  subnet_id     = aws_subnet.common-subnet-public-1.id

  tags = {
    Name = "nat-gw-a"
  }
}

resource "aws_nat_gateway" "nat-gw-b" {
  allocation_id = aws_eip.nat2.id
  subnet_id     = aws_subnet.common-subnet-public-2.id

  tags = {
    Name = "nat-gw-b"
  }
}

## Private Route Tables

resource "aws_route_table" "common-private-route-table-a" {
    vpc_id = aws_vpc.common-vpc.id

    route {
        //associated subnet can reach everywhere
        cidr_block = "0.0.0.0/0"         //CRT uses this IGW to reach internet
        gateway_id = aws_nat_gateway.nat-gw-a.id
    }

    tags = {
        Name = "common-private-route-table-a"
    }
}

resource "aws_route_table" "common-private-route-table-b" {
    vpc_id = aws_vpc.common-vpc.id

    route {
        //associated subnet can reach everywhere
        cidr_block = "0.0.0.0/0"         //CRT uses this IGW to reach internet
        gateway_id = aws_nat_gateway.nat-gw-b.id
    }

    tags = {
        Name = "common-private-route-table-b"
    }
}

## Private Route Tables Associations

resource "aws_route_table_association" "common-crta-private-subnet-1"{
    subnet_id = aws_subnet.common-subnet-private-1.id
    route_table_id = aws_route_table.common-private-route-table-a.id
}
resource "aws_route_table_association" "common-crta-private-subnet-2"{
    subnet_id = aws_subnet.common-subnet-private-2.id
    route_table_id = aws_route_table.common-private-route-table-b.id
}
