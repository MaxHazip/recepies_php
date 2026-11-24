-- "Кухни мира" — учебная схема для чистого PHP + MariaDB / MySQL.
-- Основана на модуле Б конкурсного задания 2027.
-- ВАЖНО: это наша самостоятельная учебная модель, а НЕ официальная схема конкурса.
-- Не запускайте файл на предоставленной организаторами базе.
-- Скрипт не удаляет существующие базы или таблицы.

CREATE DATABASE IF NOT EXISTS recipes_training
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE recipes_training;
SET NAMES utf8mb4;

-- 1. Аккаунты администратора и обычных пользователей.
CREATE TABLE IF NOT EXISTS users (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    email VARCHAR(254) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role ENUM('admin', 'user') NOT NULL DEFAULT 'user',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_users_email (email)
) ENGINE=InnoDB;

-- 2. Bearer-токены. Храним хеш секретной части токена, а не исходный токен.
CREATE TABLE IF NOT EXISTS api_tokens (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id BIGINT UNSIGNED NOT NULL,
    token_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at DATETIME NULL,
    last_used_at DATETIME NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_api_tokens_hash (token_hash),
    KEY idx_api_tokens_user (user_id),
    CONSTRAINT fk_api_tokens_user FOREIGN KEY (user_id)
        REFERENCES users (id) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- 3. Категории рецептов: нельзя удалить категорию с рецептами.
CREATE TABLE IF NOT EXISTS categories (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    name VARCHAR(40) NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_categories_name (name)
) ENGINE=InnoDB;

-- 4. Справочник ингредиентов. Единица измерения привязана к ингредиенту.
CREATE TABLE IF NOT EXISTS ingredients (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    title VARCHAR(20) NOT NULL,
    unit ENUM('шт', 'л', 'кг', 'мг', 'ст.л.') NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_ingredients_title (title)
) ENGINE=InnoDB;

-- 5. Рецепты, включая мягкое удаление.
-- Цена 0 допускается для бесплатных рецептов (они есть в примерах API).
CREATE TABLE IF NOT EXISTS recipes (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    category_id BIGINT UNSIGNED NOT NULL,
    title VARCHAR(20) NOT NULL,
    description VARCHAR(250) NOT NULL,
    cooking_time INT UNSIGNED NOT NULL,
    difficulty ENUM('легко', 'средне', 'сложно') NOT NULL,
    price DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    deleted_at DATETIME NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_recipes_category (category_id),
    KEY idx_recipes_visible_newest (deleted_at, created_at, id),
    KEY idx_recipes_cooking_time (cooking_time),
    KEY idx_recipes_difficulty (difficulty),
    KEY idx_recipes_price (price),
    CONSTRAINT chk_recipes_cooking_time CHECK (cooking_time > 0),
    CONSTRAINT chk_recipes_price CHECK (price = 0 OR price > 100),
    CONSTRAINT fk_recipes_category FOREIGN KEY (category_id)
        REFERENCES categories (id) ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- 6. Оригиналы изображений, версии с водяным знаком и миниатюры WebP.
-- Ограничения на >=2 изображения, размер/формат файла и единственную
-- картинку по умолчанию проверяем в PHP при создании/редактировании.
CREATE TABLE IF NOT EXISTS recipe_images (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    recipe_id BIGINT UNSIGNED NOT NULL,
    original_path VARCHAR(500) NOT NULL,
    image_path VARCHAR(500) NOT NULL,
    thumbnail_path VARCHAR(500) NOT NULL,
    is_default TINYINT(1) NOT NULL DEFAULT 0,
    sort_order INT UNSIGNED NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_images_recipe (recipe_id),
    CONSTRAINT chk_images_default CHECK (is_default IN (0, 1)),
    CONSTRAINT fk_images_recipe FOREIGN KEY (recipe_id)
        REFERENCES recipes (id) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- 7. Связь многие-ко-многим: рецепт ↔ ингредиент, с количеством.
CREATE TABLE IF NOT EXISTS recipe_ingredients (
    recipe_id BIGINT UNSIGNED NOT NULL,
    ingredient_id BIGINT UNSIGNED NOT NULL,
    quantity DECIMAL(12,3) NOT NULL,
    PRIMARY KEY (recipe_id, ingredient_id),
    KEY idx_recipe_ingredients_ingredient (ingredient_id),
    CONSTRAINT chk_recipe_ingredients_quantity CHECK (quantity > 0),
    CONSTRAINT fk_recipe_ingredients_recipe FOREIGN KEY (recipe_id)
        REFERENCES recipes (id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_recipe_ingredients_ingredient FOREIGN KEY (ingredient_id)
        REFERENCES ingredients (id) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- 8. Шаги каждого рецепта. step_order -> поле "order" в JSON API.
CREATE TABLE IF NOT EXISTS recipe_steps (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    recipe_id BIGINT UNSIGNED NOT NULL,
    title VARCHAR(40) NOT NULL,
    description VARCHAR(255) NOT NULL,
    step_order INT UNSIGNED NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_steps_recipe_order (recipe_id, step_order),
    CONSTRAINT chk_recipe_steps_order CHECK (step_order > 0),
    CONSTRAINT fk_steps_recipe FOREIGN KEY (recipe_id)
        REFERENCES recipes (id) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- 9. Избранное: один пользователь не может добавить один рецепт дважды.
CREATE TABLE IF NOT EXISTS favorites (
    user_id BIGINT UNSIGNED NOT NULL,
    recipe_id BIGINT UNSIGNED NOT NULL,
    favorited_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, recipe_id),
    KEY idx_favorites_recipe (recipe_id),
    CONSTRAINT fk_favorites_user FOREIGN KEY (user_id)
        REFERENCES users (id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_favorites_recipe FOREIGN KEY (recipe_id)
        REFERENCES recipes (id) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- 10. Покупки: несколько платежных попыток для пары user/recipe допустимы.
-- Успешное владение, повторные попытки и правила переходов статусов
-- проверяются в PHP (при необходимости с транзакцией/блокировкой).
CREATE TABLE IF NOT EXISTS purchases (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id BIGINT UNSIGNED NOT NULL,
    recipe_id BIGINT UNSIGNED NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    status ENUM('pending', 'paid', 'failed', 'expired') NOT NULL DEFAULT 'pending',
    webhook_lookup_hash CHAR(32) CHARACTER SET ascii COLLATE ascii_bin NULL,
    paid_at DATETIME NULL,
    expires_at DATETIME NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_purchases_webhook_hash (webhook_lookup_hash),
    KEY idx_purchases_user_created (user_id, created_at),
    KEY idx_purchases_recipe (recipe_id),
    KEY idx_purchases_status_expiry (status, expires_at),
    CONSTRAINT chk_purchases_amount CHECK (total_amount > 0),
    CONSTRAINT fk_purchases_user FOREIGN KEY (user_id)
        REFERENCES users (id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_purchases_recipe FOREIGN KEY (recipe_id)
        REFERENCES recipes (id) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- 11. Прохождение шагов внутри конкретной покупки.
-- Соответствие step_id рецепту покупки и право пользователя проверяем в PHP.
CREATE TABLE IF NOT EXISTS step_progress (
    purchase_id BIGINT UNSIGNED NOT NULL,
    step_id BIGINT UNSIGNED NOT NULL,
    completed TINYINT(1) NOT NULL DEFAULT 1,
    completed_at DATETIME NULL,
    PRIMARY KEY (purchase_id, step_id),
    KEY idx_step_progress_step (step_id),
    CONSTRAINT chk_progress_completed CHECK (completed IN (0, 1)),
    CONSTRAINT fk_progress_purchase FOREIGN KEY (purchase_id)
        REFERENCES purchases (id) ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_progress_step FOREIGN KEY (step_id)
        REFERENCES recipe_steps (id) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- --------------------------------------------------------------
-- Учебные данные. Пароли соответствуют тестовым из конкурсного задания,
-- но в БД лежат bcrypt-хеши, сгенерированные password_hash() в PHP.
-- Только для локальной учебной базы. Внешние учётные данные не трогаем.
-- --------------------------------------------------------------

INSERT INTO users (email, password_hash, role)
VALUES
  ('admin@champ2026.lan', '$2y$12$pLc3sefKWK8yPikY1Ozl2uQ..c4Pv.GUWg0f10VrFBxPeiY.S0x0.', 'admin'),
  ('user@champ2026.lan', '$2y$12$vbKEMUWEVLizrfw7BH/S0..YpyuMfQgDFsGWCEjSVVwoZghfuUedy', 'user')
ON DUPLICATE KEY UPDATE role = VALUES(role);

INSERT IGNORE INTO categories (name) VALUES
  ('Первые блюда'),
  ('Основные блюда'),
  ('Салаты'),
  ('Десерты');

INSERT IGNORE INTO ingredients (title, unit) VALUES
  ('Свекла', 'кг'),
  ('Картофель', 'кг'),
  ('Капуста', 'кг'),
  ('Морковь', 'кг'),
  ('Мука', 'кг'),
  ('Мясо', 'кг'),
  ('Вода', 'л');

-- Демонстрационные рецепты: нужны для проверки чтения API до урока
-- загрузки изображений. Они добавляются напрямую SQL, поэтому картинки
-- пока отсутствуют; так нельзя обходить правила валидации админ-формы.
INSERT INTO recipes (category_id, title, description, cooking_time, difficulty, price)
SELECT c.id, 'Борщ',
       'Традиционный овощной суп со свеклой, капустой и картофелем. Подаётся горячим и подходит для семейного обеда.',
       120, 'средне', 0.00
FROM categories c
WHERE c.name = 'Первые блюда'
  AND NOT EXISTS (SELECT 1 FROM recipes WHERE title = 'Борщ');

INSERT INTO recipes (category_id, title, description, cooking_time, difficulty, price)
SELECT c.id, 'Пельмени',
       'Домашние пельмени с мясной начинкой, приготовленные по пошаговому мастер-классу. Рецепт подходит для семейного ужина.',
       90, 'сложно', 500.00
FROM categories c
WHERE c.name = 'Основные блюда'
  AND NOT EXISTS (SELECT 1 FROM recipes WHERE title = 'Пельмени');

INSERT IGNORE INTO recipe_ingredients (recipe_id, ingredient_id, quantity)
SELECT r.id, i.id, 0.300 FROM recipes r JOIN ingredients i ON i.title = 'Свекла' WHERE r.title = 'Борщ';
INSERT IGNORE INTO recipe_ingredients (recipe_id, ingredient_id, quantity)
SELECT r.id, i.id, 0.400 FROM recipes r JOIN ingredients i ON i.title = 'Картофель' WHERE r.title = 'Борщ';
INSERT IGNORE INTO recipe_ingredients (recipe_id, ingredient_id, quantity)
SELECT r.id, i.id, 0.250 FROM recipes r JOIN ingredients i ON i.title = 'Капуста' WHERE r.title = 'Борщ';
INSERT IGNORE INTO recipe_ingredients (recipe_id, ingredient_id, quantity)
SELECT r.id, i.id, 0.500 FROM recipes r JOIN ingredients i ON i.title = 'Мука' WHERE r.title = 'Пельмени';
INSERT IGNORE INTO recipe_ingredients (recipe_id, ingredient_id, quantity)
SELECT r.id, i.id, 0.600 FROM recipes r JOIN ingredients i ON i.title = 'Мясо' WHERE r.title = 'Пельмени';

INSERT IGNORE INTO recipe_steps (recipe_id, title, description, step_order)
SELECT id, 'Подготовка', 'Нарежьте овощи и подготовьте ингредиенты.', 1 FROM recipes WHERE title = 'Борщ';
INSERT IGNORE INTO recipe_steps (recipe_id, title, description, step_order)
SELECT id, 'Приготовление', 'Варите овощи до готовности и добавьте специи.', 2 FROM recipes WHERE title = 'Борщ';
INSERT IGNORE INTO recipe_steps (recipe_id, title, description, step_order)
SELECT id, 'Тесто', 'Замесите тесто и дайте ему отдохнуть.', 1 FROM recipes WHERE title = 'Пельмени';
INSERT IGNORE INTO recipe_steps (recipe_id, title, description, step_order)
SELECT id, 'Лепка', 'Разложите начинку и слепите пельмени.', 2 FROM recipes WHERE title = 'Пельмени';

-- Быстрый контроль успешного импорта.
SELECT 'users' AS table_name, COUNT(*) AS total FROM users
UNION ALL SELECT 'categories', COUNT(*) FROM categories
UNION ALL SELECT 'ingredients', COUNT(*) FROM ingredients
UNION ALL SELECT 'recipes', COUNT(*) FROM recipes
UNION ALL SELECT 'recipe_steps', COUNT(*) FROM recipe_steps;
