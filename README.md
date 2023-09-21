# JBrowse2 Containerized Service

To run this service using `docker run`, use:

**How to build:**
```
docker build -t jbrowse2 .
```
**How to run:**
```
docker run --rm jbrowse2:latest
```

# Example of how to dynamically add tracks from inside the container
```
> jbrowse add-assembly PlasmoDB-61_Pfalciparum3D7_Genome.fa --load copy --out /usr/local/apache2/htdocs/
> jbrowse add-track sorted_PlasmoDB-61_Pfalciparum3D7.gff.gz --load copy --out /usr/local/apache2/htdocs/
```
