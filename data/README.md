# Data

The full source dataset is not included in this repository because of its size.

## Source Dataset

**Dataset:** SmartMeter Energy Consumption Data in London Households  
**Publisher:** UK Power Networks / London Datastore

The dataset contains half-hourly electricity consumption readings collected from London households between November 2011 and February 2014.

This project uses the partitioned version of the dataset for Microsoft Fabric ingestion.

### Dataset Used

- 168 CSV files
- Approximately 7.96 GB extracted
- 167,932,474 source records processed
- Standard (`Std`) and Time-of-Use (`ToU`) household groups
- Half-hourly electricity consumption readings

## Additional Reference Data

The project also uses the supplied `Tariffs.xlsx` workbook.

The workbook contains the 2013 dynamic Time-of-Use tariff schedule at 30-minute intervals, classified as:

- High
- Normal
- Low

The workbook is used as reference data for tariff-band enrichment. It does not contain the tariff prices used in the original trial documentation.

## Data Access

The original dataset is publicly available from the London Datastore:

https://data.london.gov.uk/dataset/smartmeter-energy-consumption-data-in-london-households-vqm0d

The project used the partitioned smart-meter archive rather than storing the full source dataset in this GitHub repository.

## Repository Sample

The `sample/` directory contains only a small representative extract for:

- Repository inspection
- Schema demonstration
- Code understanding
- Portfolio review

It is not intended to reproduce the full-scale Fabric processing workload.

## Data Architecture

The full dataset follows this path in Microsoft Fabric:

`London Datastore → Data Factory Pipeline → OneLake Landing → Bronze → Silver → Gold`

The complete dataset remains external to this repository because publishing multi-gigabyte source files to GitHub is unnecessary and impractical.

## Data Privacy

Households are represented by pseudonymous identifiers supplied in the public source dataset. No additional personally identifiable information is introduced by this project.
