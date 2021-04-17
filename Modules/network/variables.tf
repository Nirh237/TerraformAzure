

variable "resource_group_name" {
description = "resource group name"
type = string
default = "myTFResorceGroup"
}

variable "location" {
    description = "location"
    type = string
    default = "westeurope"

}

variable "vnet" {
    description = "Vnet CIDR"
    type = list
    default = ["10.0.0.0/16"]
    
}


variable "vm_size" {
description = "vm size"
type = string
default = "Standard_DS1_v2"
}

variable "admin_username" {
description = "admin_username"
type = string
}

variable "admin_password" {
description = "admin_password"
type = string
}