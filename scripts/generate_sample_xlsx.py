import csv
import openpyxl

wb = openpyxl.Workbook()
ws = wb.active
ws.title = "TRIM DIE-2"

with open("test/fixtures/sample_bom.csv", "r", encoding="utf-8") as f:
    reader = csv.reader(f)
    for row in reader:
        ws.append(row)

output_path = "test/fixtures/TRIM DIE-2 546761408201 PATCH PLATE BOM.xlsx"
wb.save(output_path)
print(f"Saved sample xlsx to {output_path}")
