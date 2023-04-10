package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"strconv"
	"time"
	"github.com/gin-gonic/gin"
	"github.com/redis/go-redis/v9"
	"github.com/kelseyhightower/envconfig"
)

// Config contains the configuration for the app.
type Config struct {
	Port          int    `envconfig:"PORT"`
	RedisHost     string `envconfig:"REDIS_HOST"`
	RedisPort     int    `envconfig:"REDIS_PORT"`
	RedisPassword string `envconfig:"REDIS_PASSWORD"`
}

// Count is the response object.
type Count struct {
	Value int `json:"count"`
}

func main() {
	var c Config
	err := envconfig.Process("app", &c)
	
	if err != nil {
		log.Fatal(err.Error())
	}
	r := redis.NewClusterClient(&redis.ClusterOptions{
        Addrs:        []string{fmt.Sprintf("%s:%d", c.RedisHost, c.RedisPort)},
        Password:     c.RedisPassword ,
    })
	router := gin.Default()

	router.GET("/:id", func(c *gin.Context) {
		ctx := context.Background()
		id := c.Param("id")
		val, err := r.Get(ctx, id).Result()
		if err != nil {
			if err == redis.Nil {
				c.JSON(http.StatusOK, Count{Value: 1})
				if err := r.Set(ctx, id, 1, time.Minute*10).Err(); err != nil {
					log.Println("failed to update cache")
				}
				return
			}
			c.String(http.StatusInternalServerError, "failed to get count")
		}
		ct, err := strconv.Atoi(val)
		if err != nil {
			log.Println("failed to parse value")
		}

		c.JSON(http.StatusOK, Count{Value: ct + 1})
		if err := r.Set(ctx, id, ct+1, time.Minute*10).Err(); err != nil {
			log.Println("failed to update cache")
		}
		return
	})
	_ = router.Run(fmt.Sprintf(":%d", c.Port))
}
