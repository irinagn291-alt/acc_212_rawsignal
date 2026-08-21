import Foundation

enum NutrientPortionCalculator {
    static func scaledEnvelope(
        perHundredGrams: NutrientMagnitudeEnvelope,
        servingGrams: Double
    ) -> NutrientMagnitudeEnvelope {
        let factor = servingGrams / 100.0
        return NutrientMagnitudeEnvelope(
            kilocalories: perHundredGrams.kilocalories * factor,
            proteinGrams: perHundredGrams.proteinGrams * factor,
            carbohydrateGrams: perHundredGrams.carbohydrateGrams * factor,
            lipidGrams: perHundredGrams.lipidGrams * factor
        )
    }

    static func kilocaloriesConvertedFromKilojoules(_ kilojoules: Double) -> Double {
        kilojoules / 4.184
    }
}
