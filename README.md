# MariaDB github action

This action sets up a MariaDB server for the rest of the job. Here are some
key features:

* Runs on Linux only for now action runners (other will be in next step).
* Can use either community, enterprise or development releases

#### Inputs

| Key                       | Description                                                                                                                                   | Default             | Required |
|---------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------|---------------------|----------|
| tag                       | Valid image tag from registry                                                                                                                 | `latest`            | No       |
| port                      | Exposed port for database connections                                                                                                         | 3306                | No       |
| registry                  | registry for MariaDB image (e.g., 'docker.io/mariadb', 'quay.io/mariadb-foundation/mariadb-devel', or 'docker.mariadb.com/enterprise-server') | `docker.io/mariadb` | No       |
| registry-user             | registry username when (mandatory when using enterprise registry)                                                                             |                     | No       |
| registry-password         | registry password when (mandatory when using enterprise registry)                                                                             |                     | No       |
| container-runtime         | Container runtime to use (docker or podman)                                                                                                   | `podman`            | No       |
| root-password             | Password for root user                                                                                                                        |                     | No       |
| allow-empty-root-password | Permits empty root password                                                                                                                   |                     | No       |
| user                      | Create a MariaDB user                                                                                                                         |                     | No       |
| password                  | Define a password for MariaDB user                                                                                                            |                     | No       |
| database                  | Initial database to create                                                                                                                    |                     | No       |
| conf-script-folder        | Additional configuration directory                                                                                                            |                     | No       |
| init-script-folder        | Initialization script directory                                                                                                               |                     | No       |


#### Community server

```yaml
steps:
  - name: Set up MariaDB
    uses: rusher/setup-mariadb@v1
    with:
      tag: '10.6'
      root-password: 'myRootPassword'
      user: 'myUser'
      password: 'MyPassw0rd'
      database: 'myDb'
```

#### enterprise

```yaml
steps:
  - name: Set up MariaDB
    uses: rusher/setup-mariadb@v1
    with:
      tag: '10.6'
      registry: 'docker.mariadb.com/enterprise-server'
      registry-user: 'myUser@mail.com'
      registry-password: 'myDockerEnterprisePwd'
      root-password: 'myRootPassword'
      user: 'myUser'
      password: 'MyPassw0rd'
      database: 'myDb' 
```

#### Development

this are development or preview versions 
see tag from https://quay.io/repository/mariadb-foundation/mariadb-devel?tab=tags&tag=latest

```yaml
steps:
  - name: Set up MariaDB
    uses: rusher/setup-mariadb@v1
    with:
      tag: '12.0-preview'
      registry: 'quay.io/mariadb-foundation/mariadb-devel'
      root-password: 'myRootPassword'
      user: 'myUser'
      password: 'MyPassw0rd'
      database: 'myDb' 
```

## License

The scripts and documentation in this project are released under the
[MIT License](LICENSE).