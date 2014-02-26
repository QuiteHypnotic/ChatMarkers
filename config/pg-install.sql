EXPLAIN ANALYZE SELECT users.id, users.username, array_agg(interests.name) AS interests, st_distance_sphere(location, 'SRID=4326;POINT(-120 35)') as distance FROM users LEFT JOIN (users_interests JOIN interests ON users_interests.interest_id = interests.id) ON users.id = users_interests.user_id WHERE available = TRUE AND location IS NOT NULL GROUP BY users.id ORDER BY location <#> 'SRID=4326;POINT(-120 35)' LIMIT 100;

// http://hackgeo.com/cloud-computing/amazon-web-services/configuring-postgresql-9-1-and-postgis-2-on-ubuntu-12-04-in-amazon-aws

$ sudo apt-get install postgresql-9.1 postgresql-server-dev-9.1 libpq-dev
$ su postgres
$ psql -d postgres -U postgres
# alter user postgres with password ‘password between these single quotes’;
# \q

$ sudo apt-add-repository ppa:sharpie/for-science  # To get GEOS 3.3.2 
$ sudo apt-add-repository ppa:sharpie/postgis-nightly
$ sudo apt-get update
$ sudo apt-get install postgresql-9.1-postgis
 
$ su postgres #change back to postgres
 
createdb -E UTF8 template_postgis2
createlang -d template_postgis2 plpgsql
psql -d postgres -c "UPDATE pg_database SET datistemplate='true' WHERE datname='template_postgis2'"
psql -d template_postgis2 -f /usr/share/postgresql/9.1/contrib/postgis-2.1/postgis.sql
psql -d template_postgis2 -f /usr/share/postgresql/9.1/contrib/postgis-2.1/spatial_ref_sys.sql
psql -d template_postgis2 -f /usr/share/postgresql/9.1/contrib/postgis-2.1/rtpostgis.sql
psql -d template_postgis2 -c "GRANT ALL ON geometry_columns TO PUBLIC;"
psql -d template_postgis2 -c "GRANT ALL ON geography_columns TO PUBLIC;"
psql -d template_postgis2 -c "GRANT ALL ON spatial_ref_sys TO PUBLIC;"


DROP TABLE users_interests;
DROP TABLE threads_users;
DROP TABLE threads_interests;
DROP TABLE threads;
DROP TABLE sessions;
DROP TABLE interets;
DROP TABLE users;


CREATE TABLE users (
    id bigserial primary key,
    name varchar(32) NOT NULL,
    username VARCHAR(32) NOT NULL,
    email varchar(256),
    password varchar(256),
    facebook_id varchar(128),
    twitter_id varchar(128),
    available boolean,
    latitude double precision,
    longitude double precision
);
SELECT AddGeometryColumn('users', 'location', 4326, 'POINT', 2);
CREATE UNIQUE INDEX index_users_email ON users USING btree (email);
CREATE UNIQUE INDEX index_users_username ON users USING btree (lower(username));
CREATE UNIQUE INDEX index_users_facebook_id ON users USING btree (facebook_id);
CREATE UNIQUE INDEX index_users_twitter_id ON users USING btree (twitter_id);

CREATE OR REPLACE FUNCTION users_update_location() RETURNS TRIGGER AS $$ BEGIN
    IF NEW.longitude IS NOT NULL AND NEW.latitude IS NOT NULL THEN 
        NEW.location = ST_GeomFromText('POINT(' || NEW.longitude || ' ' || NEW.latitude || ')', 4326);
    END IF;
    RETURN NEW;
END; $$ LANGUAGE 'plpgsql';

CREATE TRIGGER trigger_users_update_location BEFORE INSERT OR UPDATE ON users FOR EACH ROW EXECUTE PROCEDURE users_update_location();


CREATE TABLE interests (
    id bigserial primary key,
    name varchar(32) NOT NULL
);
CREATE UNIQUE INDEX index_interests_name ON interests USING btree (lower(name));


CREATE TABLE users_interests (
    user_id bigserial,
    interest_id bigserial,
    CONSTRAINT fk_thread FOREIGN KEY (user_id)
        REFERENCES users (id) MATCH SIMPLE
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_user FOREIGN KEY (interest_id)
        REFERENCES interests (id) MATCH SIMPLE
        ON UPDATE CASCADE ON DELETE CASCADE
);
CREATE UNIQUE INDEX index_users_interests_user_interest ON users_interests USING btree (user_id,interest_id);
CREATE UNIQUE INDEX index_users_interests_interest_user ON users_interests USING btree (interest_id,user_id);


CREATE TABLE sessions (
    id bigserial primary key,
    user_id bigserial NOT NULL,
    ip_address VARCHAR(45) NOT NULL,
    device_id VARCHAR(128),
    device_type VARCHAR(10),
    token VARCHAR(128) NOT NULL,
    created_time timestamp NOT NULL,
    CONSTRAINT fk_user FOREIGN KEY (user_id)
        REFERENCES users (id) MATCH SIMPLE
        ON UPDATE CASCADE ON DELETE CASCADE
);
CREATE INDEX index_sessions_token ON sessions USING btree (token);


CREATE TABLE threads (
    id bigserial primary key,
    name varchar(32) NOT NULL,
    password varchar(256),
    interests text[],
    expiration timestamp,
    latitude double precision,
    longitude double precision,
    owner_id bigserial,
    CONSTRAINT fk_user FOREIGN KEY (owner_id)
        REFERENCES users (id) MATCH SIMPLE
        ON UPDATE CASCADE ON DELETE CASCADE
);
SELECT AddGeometryColumn('threads', 'location', 4326, 'POINT', 2);

CREATE OR REPLACE FUNCTION threads_update_location() RETURNS TRIGGER AS $$ BEGIN
    IF NEW.longitude IS NOT NULL AND NEW.latitude IS NOT NULL THEN 
        NEW.location = ST_GeomFromText('POINT(' || NEW.longitude || ' ' || NEW.latitude || ')', 4326);
    END IF;
    RETURN NEW;
END; $$ LANGUAGE 'plpgsql';

CREATE TRIGGER trigger_threads_update_location BEFORE INSERT OR UPDATE ON threads FOR EACH ROW EXECUTE PROCEDURE threads_update_location();


CREATE TABLE threads_users (
    thread_id bigserial,
    user_id bigserial,
    subscribed boolean,
    CONSTRAINT fk_thread FOREIGN KEY (thread_id)
        REFERENCES threads (id) MATCH SIMPLE
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_user FOREIGN KEY (user_id)
        REFERENCES users (id) MATCH SIMPLE
        ON UPDATE CASCADE ON DELETE CASCADE
);
CREATE UNIQUE INDEX index_threads_users_thread_user ON threads_users USING btree (thread_id,user_id);
CREATE UNIQUE INDEX index_threads_users_user_thread ON threads_users USING btree (user_id,thread_id);


CREATE TABLE threads_interests (
    thread_id bigserial,
    interest_id bigserial,
    CONSTRAINT fk_thread FOREIGN KEY (thread_id)
        REFERENCES threads (id) MATCH SIMPLE
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_user FOREIGN KEY (interest_id)
        REFERENCES interests (id) MATCH SIMPLE
        ON UPDATE CASCADE ON DELETE CASCADE
);


SELECT users.id, users.username, array_agg(interests.name), st_distance_sphere(location, 'SRID=4326;POINT(-9.76942322216928 -48.8199596246704)') as distance FROM users LEFT JOIN (users_interests JOIN interests ON users_interests.interest_id = interests.id) ON users_interests.user_id = users.id WHERE ST_Within(location, ST_Buffer('SRID=4326;POINT(-9.76942322216928 -48.8199596246704)', 10)) GROUP BY users.id LIMIT 100;
