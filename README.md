# jbrowse2

To run this service using `docker run`, use:
```
**How to build:**

docker build -t rserve Rserve/ --no-cache

**How to run:**

docker run --rm rserve:latest
```

jbrowse add-assembly PlasmoDB-61_Pfalciparum3D7_Genome.fa --load copy --out /usr/local/apache2/htdocs/

jbrowse add-track sorted_PlasmoDB-61_Pfalciparum3D7.gff.gz --load copy --out /usr/local/apache2/htdocs/