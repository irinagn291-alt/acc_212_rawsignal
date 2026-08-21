import Foundation

enum LocalShelfCatalogFactory {
    static func eightPulseStaples() -> [CatalogMerchandiseRecord] {
        [
            record("RS-SHELF-OAT", "Graphite Oat Brick", "PULSE MILL", 389, 16.9, 66.3, 6.9, 80, "ShelfGraphiteOat"),
            record("RS-SHELF-BEAN", "Crimson Bean Pulse", "GRID LEGUME", 127, 8.7, 22.8, 0.5, 150, "ShelfCrimsonBean"),
            record("RS-SHELF-RICE", "Neutral Rice Slab", "STATIC STARCH", 130, 2.7, 28.0, 0.3, 180, "ShelfNeutralRice"),
            record("RS-SHELF-ALM", "Volt Almond Paste", "SIGNAL NUT", 614, 21.0, 21.6, 49.9, 30, "ShelfVoltAlmond"),
            record("RS-SHELF-BERRY", "Static Berry Cube", "NOISE FRUIT", 57, 0.7, 14.5, 0.3, 100, "ShelfStaticBerry"),
            record("RS-SHELF-LENTIL", "Carbon Lentil Mash", "VOID POD", 116, 9.0, 20.1, 0.4, 160, "ShelfCarbonLentil"),
            record("RS-SHELF-TUNA", "Signal Tuna Block", "PULSE CATCH", 132, 28.0, 0.0, 1.3, 110, "ShelfSignalTuna"),
            record("RS-SHELF-YOG", "Noise Yogurt Disk", "RAW CULTURE", 61, 10.0, 3.6, 0.4, 170, "ShelfNoiseYogurt")
        ]
    }

    private static func record(
        _ sku: String,
        _ title: String,
        _ brand: String,
        _ kcal: Double,
        _ protein: Double,
        _ carbs: Double,
        _ fat: Double,
        _ grams: Double,
        _ asset: String
    ) -> CatalogMerchandiseRecord {
        CatalogMerchandiseRecord(
            identifier: sku,
            stockKeepingUnit: sku,
            displayTitle: title,
            brandLine: brand,
            energyPerHundredGrams: kcal,
            proteinPerHundredGrams: protein,
            carbohydratePerHundredGrams: carbs,
            lipidPerHundredGrams: fat,
            defaultServingGrams: grams,
            artworkAssetName: asset
        )
    }
}

enum SimulatorShelfSeeder {
    static func applyIfNeeded(vault: SignalVaultPersisting) {
        var envelope = vault.loadEnvelope()
        if envelope.localShelf.isEmpty {
            envelope.localShelf = LocalShelfCatalogFactory.eightPulseStaples()
        }
        #if targetEnvironment(simulator)
        let calendar = Calendar.current
        let todayProbe = calendar.startOfDay(for: Date())
        let eatenToday = envelope.consumptionLog.contains { calendar.isDate($0.calendarDay, inSameDayAs: todayProbe) }
        if envelope.seedApplied && !eatenToday {
            envelope.seedApplied = false
            envelope.consumptionLog.removeAll { $0.identifier.hasPrefix("SEED-") }
            envelope.horizonPlans.removeAll { $0.identifier.hasPrefix("SEED-") }
            envelope.wishLedger.removeAll { $0.identifier.hasPrefix("SEED-") }
        }
        #endif
        if !envelope.seedApplied, envelope.localShelf.count >= 7 {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
            let oat = envelope.localShelf[0]
            let tuna = envelope.localShelf[6]
            let rice = envelope.localShelf[2]
            let berry = envelope.localShelf[4]
            let yogurt = envelope.localShelf[7]
            envelope.consumptionLog.append(contentsOf: [
                consumption("SEED-TODAY-A", today, .pulseA, oat),
                consumption("SEED-TODAY-B", today, .pulseB, tuna),
                consumption("SEED-TODAY-C", today, .noise, berry)
            ])
            envelope.horizonPlans.append(
                HorizonPlanEntry(
                    identifier: "SEED-PLAN-A",
                    calendarDay: tomorrow,
                    laneKind: .pulseC,
                    merchandise: rice,
                    servingGrams: rice.defaultServingGrams,
                    computedMagnitudes: NutrientPortionCalculator.scaledEnvelope(
                        perHundredGrams: rice.perHundredEnvelope,
                        servingGrams: rice.defaultServingGrams
                    )
                )
            )
            envelope.wishLedger.append(
                WishLedgerItem(
                    identifier: "SEED-WISH-YOG",
                    stockKeepingUnit: yogurt.stockKeepingUnit,
                    merchandise: yogurt
                )
            )
            envelope.seedApplied = true
        }
        vault.persistEnvelope(envelope)
    }

    private static func consumption(
        _ id: String,
        _ day: Date,
        _ lane: PulseLaneKind,
        _ merchandise: CatalogMerchandiseRecord
    ) -> DailyConsumptionEntry {
        DailyConsumptionEntry(
            identifier: id,
            calendarDay: day,
            laneKind: lane,
            merchandise: merchandise,
            servingGrams: merchandise.defaultServingGrams,
            computedMagnitudes: NutrientPortionCalculator.scaledEnvelope(
                perHundredGrams: merchandise.perHundredEnvelope,
                servingGrams: merchandise.defaultServingGrams
            )
        )
    }
}
