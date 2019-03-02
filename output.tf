output "wiki" {
  value = "${aws_instance.haproxy.public_ip}"
}
