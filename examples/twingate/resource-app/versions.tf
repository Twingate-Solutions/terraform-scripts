terraform {
  required_version = ">= 1.0"

  required_providers {
    twingate = {
      source  = "twingate/twingate"
      version = ">= 3.0"
    }
  }
}