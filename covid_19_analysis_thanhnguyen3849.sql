-- Data analysis using SQL
-- Join 2 tables based on date and location
Select *
From p_project..covid_death cd
Join p_project..covid_vac cv
	On cd.location = cv.location
	and cd.date = cv.date

-- How many people on the world have been vaccinated?
SELECT	cd.continent, 
		cd.location, 
		cd.date, 
		cd.population, 
		cv.new_vaccinations,
		SUM(cast(cv.new_vaccinations as float)) 
			OVER (PARTITION BY cd.location ORDER BY cd.location, cd.date) as rolling_vaccinations
FROM p_project..covid_death cd
JOIN p_project..covid_vac cv
	ON cd.location = cv.location
	and cd.date = cv.date
WHERE cd.continent is not null
ORDER BY 2,3

-- First approach, use CTE
WITH pop_vaccinations (continent, location, date, population, new_vaccinations, rolling_vaccinations)
AS
(
SELECT	cd.continent, 
		cd.location, 
		cd.date, 
		cd.population, 
		cv.new_vaccinations,
		SUM(cast(cv.new_vaccinations as float)) 
			OVER (PARTITION BY cd.location ORDER BY cd.location, cd.date) as rolling_vaccinations
FROM p_project..covid_death cd
JOIN p_project..covid_vac cv
	ON cd.location = cv.location
	and cd.date = cv.date
WHERE cd.continent is not null
)

SELECT *, (rolling_vaccinations/population)*100 as vac_percentage
FROM pop_vaccinations

-- Second approach, use temp table
Alter table p_project..covid_vac
Alter column new_vaccinations float;

DROP TABLE IF EXISTS #pop_vac
CREATE TABLE #pop_vac
(
continent nvarchar(255),
location nvarchar(255),
date datetime,
population numeric,
new_vaccinations numeric,
rolling_vac numeric
)

INSERT INTO #pop_vac
SELECT	cd.continent, 
		cd.location, 
		cd.date, 
		cd.population, 
		cv.new_vaccinations,
		SUM(cv.new_vaccinations)
			OVER (PARTITION BY cd.location ORDER BY cd.location, cd.date) as rolling_vac
FROM p_project..covid_death cd
JOIN p_project..covid_vac cv
	ON cd.location = cv.location
	and cd.date = cv.date
WHERE cd.continent is not null

SELECT *, (rolling_vac/population)*100 as vac_percentage
FROM #pop_vac

-- Create a View to store data for later visualization 
CREATE VIEW percentage_population_vaccinated as
SELECT	cd.continent, 
		cd.location, 
		cd.date, 
		cd.population, 
		cv.new_vaccinations,
		SUM(CONVERT(int,cv.new_vaccinations))
			OVER (PARTITION BY cd.location ORDER BY cd.location, cd.date) as rolling_vac
FROM p_project..covid_death cd
JOIN p_project..covid_vac cv
	ON cd.location = cv.location
	and cd.date = cv.date
WHERE cd.continent is not null

-- Codes used to create tables for visualization
-- 1. Total death percentage worldwide
Select	SUM(new_cases) as total_cases, 
		SUM(new_deaths) as total_deaths, 
		SUM(new_deaths)/SUM(new_cases)*100 as death_pct
From p_project..covid_death
Where continent is not null 
Order by 1,2

-- 2. Total death counts per continent
-- European Union is part of Europe
Select	location, 
		SUM(new_deaths) as total_death_count
From	p_project..covid_death
Where	continent is null 
		and location not in ('World', 'European Union', 'International','High income','Upper middle income','Lower middle income','Low income')
Group by location
Order by total_death_count desc

-- 3. Percentage of total population being affected per location/country
Select	location, population,
		MAX(total_cases) as highest_infection_count,
		MAX((total_cases/NULLIF(population,0)))*100 as percentage_pop_infected
From	p_project..covid_death
Where	continent is not null
Group by	location, population
Order by	percentage_pop_infected desc

-- 4. Covid deaths over time 
Select	location, population, date,
		MAX(total_cases) as highest_infection_count,
		MAX((total_cases/NULLIF(population,0)))*100 as percentage_pop_infected
From	p_project..covid_death
Group by	location, population, date
Order by	percentage_pop_infected desc

-- Change data type
Alter table p_project..covid_death
Alter column new_cases float;
Alter table p_project..covid_death
Alter column new_deaths float;
Alter table p_project..covid_death
Alter column total_cases float;
Alter table p_project..covid_death
Alter column population float;