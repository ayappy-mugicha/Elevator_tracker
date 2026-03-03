-- __DB_NAME__ と __TABLE_NAME__ をスクリプトで置換します
CREATE DATABASE IF NOT EXISTS `__DB_NAME__` 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

USE `__DB_NAME__`;

CREATE TABLE IF NOT EXISTS `__TABLE_NAME__` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `elevator_id` VARCHAR(10) NOT NULL,
    `current_floor` INT NOT NULL,
    `occupancy` INT NOT NULL,
    `direction` VARCHAR(10) NOT NULL,
    `timestamp` DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    INDEX `ix___TABLE_NAME___id` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;