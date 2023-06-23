provider "aws" {
  profile = "KapuaNonProd_AWSAdministratorAccess"

  default_tags {
    tags = local.default_tags
  }
}
