resource "aws_key_pair" "node_key" {
  key_name   = "mynkp"
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_instance" "bastion" {
  ami                         = var.ec2_ami_id
  instance_type               = var.ec2_type_bastion
  subnet_id                   = aws_subnet.nkp_public.id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  associate_public_ip_address = true

  iam_instance_profile = aws_iam_instance_profile.nkp_bootstrap_profile.name
  key_name             = aws_key_pair.node_key.key_name

  tags = {
    Name = "${var.resource_prefix}-bastion"
  }

  user_data = file("cloud-init-bastion.yaml")

  root_block_device {
    volume_type = "gp2"
    volume_size = "50"
  }
}