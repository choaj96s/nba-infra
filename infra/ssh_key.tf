resource "aws_key_pair" "ec2_key" {
  key_name   = "nba-ec2-key"
  public_key = file("~/.ssh/nba_ec2.pub")
}
