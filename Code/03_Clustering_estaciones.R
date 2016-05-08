library(cluster)
library(plyr)

# Lectura del archivo de estaciones
getwd()
setwd("C:/Users/Alberto/compartido/Master-in-Data-Science/Proyecto/datos")
getwd()
# Lectura de todas las estaciones metereorologicas
stations <- read.csv("ghcnd-stations.csv",sep=";")
stations$ALTITUDE <- NULL

# Lectura del catálogo de estados proporcionado por la NOAA
cat_states <- read.csv("ghcnd-states.csv",sep=";")
# Lectura del catálogo de paises proporcionado por la NOAA, modificado para añadir el número de km2 por pais
cat_countries <- read.csv("ghcnd-countries.csv")

# Agregamos el número de estaciones por cada pais
stations_by_country <- ddply(stations, .(COUNTRY), c("nrow"))
colnames(stations_by_country) <- c("COUNTRY","STATIONS")

# A la tabla de paises, se añade el número de estaciones
cat_countries <- merge(cat_countries,stations_by_country,by.x="COUNTRY",by.y="COUNTRY",all.x=TRUE)
cat_countries$average_km2 <- cat_countries$SUPERFICIE / cat_countries$STATIONS
rm(stations_by_country)

# Calculo de la media de km2 por estacion a nivel mundial
average_km2 <- sum(cat_countries$SUPERFICIE) / sum(cat_countries$STATIONS)

# Hay una media de 1,474 Km2 por estacion, por tanto como tenemos ciertos paises con una media mucho más baja, intentaremos reducir el numero de estaciones
# en esos paises para que no estén sobrerepresentados

# Nos quedamos con todos aquellos paises que tienen una media por Km2 interior a la media mundia, y tenga al menos 100 estaciones de observacion

countries_to_reduce <- cat_countries[cat_countries$average_km2 < average_km2 & cat_countries$STATIONS > 100,]
nrow(countries_to_reduce)

# Como hay paises pequeños con muchas estaciones, salen casos en que ciertos paises se quedan con muy pocas estaciones, en ese caso consideramos
# que deben tener un mínimo de 50 estaciones para aplicar el algoritmo de clustering
countries_to_reduce$new_stations <- as.integer(countries_to_reduce$SUPERFICIE/average_km2)
rm(average_km2)

# como ciertos paises están divididos territorialmente por estados, calculamos el porcentaje de estaciones con las que nos quedamos
countries_to_reduce$rate <- countries_to_reduce$new_stations/countries_to_reduce$STATIONS

# Aplicamos el proceso de reducción de los paises identificados
# En primer lugar guardamos en un nuevo dataframe todas las estaciones de paises que no vamos a tocar
new_stations <- data.frame(stations);

for (i in countries_to_reduce$COUNTRY)
  new_stations <- new_stations[new_stations$COUNTRY != i,]
  
new_stations$ORIG_ID <- new_stations$ID
new_stations$ORIG_NAME <- new_stations$NAME
new_stations$ORIG_LAT <- new_stations$LATITUDE
new_stations$ORIG_LNG <- new_stations$LONGITUDE
new_stations$cluster <- 0

# Para cada pais en el countries_to_reduce dataframe, iteramos para realizar la reduccion del numero de estaciones
for (country in countries_to_reduce$COUNTRY){
  # Se recuperan los indicadores necesarios
  country_name <- cat_countries[cat_countries$COUNTRY == country, "NAME"]  
  country_rate <- countries_to_reduce[countries_to_reduce$COUNTRY == country, "rate"]
  
  # Se calcula la agregación de stationes por cada uno de los estados del pais  
  states <- ddply(stations[stations$COUNTRY == country,], .(STATE), c("nrow"))
  
  # Se itera para cada estado del pais
  for (state in states$STATE){
    # Se recupera el número de estaciones que tiene el estado
    state_name <- cat_states[cat_states == state, "NAME"]
    stations_number <- states[states$STATE == state, "nrow"]
    
    # Nos quedamos con las estaciones del estado seleccionado
    stations_state <- stations[stations$COUNTRY == country,][stations[stations$COUNTRY == country,]$STATE == state,c("ID","LATITUDE","LONGITUDE","NAME")]
    names(stations_state) <- c("ORIG_ID","ORIG_LAT","ORIG_LNG","NAME")
    
    # Representacion grafica de las estaciones del estado
    plot(stations_state$ORIG_LNG,
         stations_state$ORIG_LAT, 
         main = paste(country_name, "-", state_name, "-", toString(stations_number), " stations"), 
         xlab = "Longitude", 
         ylab="Latitude")
    
    
    # Incluso dividiendo los paises con mayor número de estaciones por estados, hay ciertas regiones que tienen un número elevado de
    # de estaciones, para ello se divide el territorio en una cuadrícula de 3x3 o 5x5 o 10x10 y se calcula el número de estaciones por celda
    celdas <- 2
    if (stations_number > 750) celdas <- 3
    if (stations_number > 2000) celdas <- 5
    if (stations_number > 5000) celdas <- 10
    
    inc_lat <- (max(stations_state$ORIG_LAT) - min(stations_state$ORIG_LAT))/celdas
    inc_lng <- (max(stations_state$ORIG_LNG) - min(stations_state$ORIG_LNG))/celdas

    distribucion_estaciones <- matrix(0,1,celdas*celdas)      
    for(c_i in 1:celdas){
      for(c_j in 1:celdas){
        coordA <- min(stations_state$ORIG_LAT) + inc_lat * c_i
        coordB <- min(stations_state$ORIG_LAT) + inc_lat * (c_i-1)
          
        coordC <- min(stations_state$ORIG_LNG) + inc_lng * c_j
        coordD <- min(stations_state$ORIG_LNG) + inc_lng * (c_j-1)

        p <- (c_i-1)*celdas+c_j
        
        if (p == celdas*celdas)
          distribucion_estaciones[p] <- nrow(stations_state[ coordB <= stations_state$ORIG_LAT & coordD <= stations_state$ORIG_LNG ,])
        else 
          distribucion_estaciones[p] <- nrow(stations_state[ coordB <= stations_state$ORIG_LAT & stations_state$ORIG_LAT < coordA & 
                                                                        coordD <= stations_state$ORIG_LNG & stations_state$ORIG_LNG < coordC,])
        rm(coordA)
        rm(coordB)
        rm(coordC)
        rm(coordD)
      }
    }

    # Se calcula la media de todas las celdas y se aplica el % de reducción aplicable al pais
    avg <- as.integer(mean(distribucion_estaciones[distribucion_estaciones > 0]) * country_rate)
      
    # En todas aquellas celdas que se supere el número obtenido, se aplica el algoritmo de clustering
    for(c_i in 1:celdas){
      for(c_j in 1:celdas){
        coordA <- min(stations_state$ORIG_LAT) + inc_lat * c_i
        coordB <- min(stations_state$ORIG_LAT) + inc_lat * (c_i-1)
        coordC <- min(stations_state$ORIG_LNG) + inc_lng * c_j
        coordD <- min(stations_state$ORIG_LNG) + inc_lng * (c_j-1)
        # Recuperamos todas las estaciones de la celda
        stations_cell <- stations_state[ coordB <= stations_state$ORIG_LAT & stations_state$ORIG_LAT < coordA & 
                                         coordD <= stations_state$ORIG_LNG & stations_state$ORIG_LNG < coordC,]
        if ((c_i-1)*celdas+c_j == celdas*celdas)
          stations_cell <- stations_state[ coordB <= stations_state$ORIG_LAT & coordD <= stations_state$ORIG_LNG,]
        
        rm(coordA)
        rm(coordB)
        rm(coordC)
        rm(coordD)
        
        # Si el número de estaciones existentes en la celda es superior al número de clusters, aplicamos el algoritmo de clustering
        if(nrow(stations_cell) > avg & avg > 10){
          # Se aplica el algoritmo de clustering sobre el conjunto de las estaciones
          cluster <- clara(stations_cell, avg)
          
          # Se incopora el cluster al conjunto de datos
          stations_cell$cluster <- cluster$clustering

          # Se recupera el medoide del cluster como ID estacion representante
          stations_cell <- merge(stations_cell,stations_cell[cluster$i.med,c("ORIG_ID","cluster","ORIG_LAT","ORIG_LNG","NAME")],by.x="cluster",by.y="cluster")
          colnames(stations_cell) <- c("cluster","ORIG_ID","ORIG_LAT","ORIG_LNG","ORIG_NAME","ID","LATITUDE","LONGITUDE","NAME")
          
          # Para que el cluster sea único por cada una de las celdas, se recodifica
          stations_cell$cluster <- ((c_i-1)*10+c_j)*1000 + stations_cell$cluster
          
          rm(cluster)
        }
        else if(nrow(stations_cell) > 0){
          # El número de estaciones por celda es inferior al obtenido, consecuentemente, almacenamos la información necesaria
          stations_cell$cluster <- 0
          stations_cell$ID <- stations_cell$ORIG_ID
          stations_cell$LATITUDE <- stations_cell$ORIG_LAT
          stations_cell$LONGITUDE <- stations_cell$ORIG_LNG
          stations_cell$ORIG_NAME <- stations_cell$NAME
        }

        if (nrow(stations_cell) > 0){      
          stations_cell$COUNTRY <- country
          stations_cell$STATE <- state
          new_stations <- rbind(new_stations,stations_cell)
          rm(stations_cell)
        }
      }
    }

    # Se muestra el mapa de las estaciones reducidas    
    n <- new_stations[new_stations$ID == new_stations$ORIG_ID & new_stations$COUNTRY == country & new_stations$STATE == state,]
    
    plot(n$ORIG_LNG,
         n$ORIG_LAT, 
         main = paste(country_name, "-", state_name, "-", toString(nrow(n)), " final stations"), 
         xlab = "Longitude", 
         ylab="Latitude")
    rm(n)
    
  }
}
    
# Almacenamos el resultado de aplicar el algoritmo de clustering sobre las estaciones
write.csv(new_stations,"ghcnd-stations-cluster.csv",sep="^")
