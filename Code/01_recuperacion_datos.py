/* Recuperacion de la informacion disponible en la NOAA de forma anual */

/* Existe un unico archivo por periodo anual, desde 1763 a 2016, por tanto generamos una descarga para cada archivo */

import urllib

/* Se itera para cada periodo anual disponible en la pagina de la NOAA */
url_base = 'ftp://ftp.ncdc.noaa.gov/pub/data/ghcn/daily/by_year/'
for x in range(1763, 2017):
    url = url_base + str(x) + '.csv.gz'
    print "Downloading " + str(x) + " year dataset"
    urllib.urlretrieve(url, "C:/temp/" + str(x) + '.csv.gz')
    



