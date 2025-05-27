terraform {
  backend "gcs" {
    bucket = "tf-state-pfe-houssam"
    prefix = "terraform/state"
  }
}