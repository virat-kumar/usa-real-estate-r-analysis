# Research proposal: U.S. real estate pricing

## Research question
Which U.S. markets offer competitively priced residential listings after controlling for size, bedrooms, bathrooms, lot size and location? How does the price-size relationship vary by market, and which properties warrant further investigation?

## Audience and relevance
Residential acquisition managers, brokerage pricing teams and expansion analysts can use price patterns for initial screening and market comparisons. This does not prove property ROI.

## Data
The [USA Real Estate Dataset](https://www.kaggle.com/datasets/ahmedshahriarsakib/usa-real-estate-dataset) on Kaggle, version 25 (last updated March 30, 2024), contains 2,226,382 listings. Observation: a property listing, with repeated geographic groupings rather than a validated longitudinal panel. **Listing date range is not documented.** Historical \`prev_sold_date\` is a previous-sale date and contains invalid/missing values.

## Models
Y: \`price\` / \`log(price)\`. X: \`house_size\`, \`bed\`, \`bath\`, \`acre_lot\`, and geographic fixed effects. Descriptive price distributions, medians, price per square foot and log-linear regression will be explored.

## Conclusions
Model outputs must be examined before making evidence-backed conclusions. Hypotheses include house-size and location premiums. Property condition, rental income, financing and renovation expenses are unavailable; the dataset alone cannot prove profitable investments.

