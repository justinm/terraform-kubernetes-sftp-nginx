terraform-kubernetes-sftp-nginx
-----

This module provides a quick persistent file based nginx server with SFTP access.

Examples
----------

    module "mysql" {
        source = "justinm/sftp-nginx/kubernetes"
        version = "5.7"
        
        name = "project-name"
        namespace = ""
        mysql_storage_size = "10Gi"
        mysql_user = "dbuser"
    }
