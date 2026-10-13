# bareos

## About

This package provides images for Bareos database migratin from MySQL to
PostgreSQL.

## Tags

darkvex/bareos-db-migration

* `latest`

## Requirements

* [Docker][docker-href] & [docker-compose][docker-compose-href]

## Usage

Since Bareos Version >= 21.0.0 the MySQL database backend is not shipped
anymore. Therefore you need to use Bareos 20 to migrate an existing MySQL
Bareos Catalog to PostgreSQL. To do so, upgrade to Bareos 20 first and then
use [this docker-compose file][compose-db-migration-href] to backup
(optional) the whole Bareos MySQL catalog and copy it into a new PostgreSQL
catalog database.

If PostgreSQL database is empty or does not exist, it will be created.

Declare environment variables or copy the `.env.dist` to `.env` and adjust its
values.

Remember that all passwords should be defined inside this `.env` file.

If `DB_BACKUP` is set to true, MySQL database will be backup.

Read carefully this docker-compose file and update MySQL/PostgreSQL verion
if required. Check PostgreSQL compatibilty information below.

```bash
docker-compose -f docker-compose.yml up
```

After sucessful migration, use the new folder `/data/pgsql/data` and the
PostgreSQL version related in your docker-compose file.

> [!NOTE]
> The migration compose file intentionally stays on `postgres:12` (the
> `pg_dump` shipped with Bareos 20 / Ubuntu focal images limits the version, see
> Compatibility below). The main stacks now run PostgreSQL 17, so after
> migrating, upgrade the new cluster from 12 straight to 17 by following the
> [PostgreSQL 12/16 to 17 wiki tutorial](https://github.com/dark-vex/bareos/wiki/Upgrade%E2%80%90PostgreSQL%E2%80%9012%E2%80%90to%E2%80%9016)
> (or go 12 -> 16 -> 17 if you prefer).

### Compatibility

The limits below apply to the migration image itself (Bareos 19/20 with
Ubuntu focal / old Alpine `pg_dump`), which is why it stays on `postgres:12`.
They are historical for the main images: the current `director-pgsql` images
(Bareos 23-25) support PostgreSQL 16, 17 and 18 (`23-alpine`: 16 and 17).

Ubuntu images:

* Bareos v19 -> PostgreSQL v10 or less
* Bareos v20+ -> PostgreSQL v12 or less

Alpine images:

* Bareos v19 -> PostgreSQL v13 or less
* Bareos v20+ -> PostgreSQL v14 or less

## Links

For more information visit the Github repositories :

* [bareos-director-pgsql](https://github.com/dark-vex/bareos/tree/master/director-pgsql)
* [bareos-storage](https://github.com/dark-vex/bareos/tree/master/storage)
* [bareos-client](https://github.com/dark-vex/bareos/tree/master/client)
* [bareos-webui](https://github.com/dark-vex/bareos/tree/master/webui)
* [docker-ubuntu](https://github.com/rockyluke/docker-ubuntu)
* [postgresql-upgrade](https://github.com/barcus/postgresql-upgrade)

My Docker hub :

* [docker images](https://hub.docker.com/r/darkvex)

Enjoy !

[compose-db-migration-href]: https://github.com/dark-vex/bareos/blob/master/bareos-db-migration/docker-compose.yml
[docker-compose-href]: https://docs.docker.com/compose
[docker-href]: https://docs.docker.com/install
