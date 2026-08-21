import XCTest
@testable import RawSignal

private func sampleMerchandise(
    sku: String = "RS-TEST-1",
    energy: Double = 200,
    protein: Double = 10,
    carbs: Double = 20,
    fat: Double = 5
) -> CatalogMerchandiseRecord {
    CatalogMerchandiseRecord(
        identifier: sku,
        stockKeepingUnit: sku,
        displayTitle: "Test Pulse Brick",
        brandLine: "UNIT",
        energyPerHundredGrams: energy,
        proteinPerHundredGrams: protein,
        carbohydratePerHundredGrams: carbs,
        lipidPerHundredGrams: fat,
        defaultServingGrams: 50,
        artworkAssetName: nil
    )
}

final class NutrientPortionCalculatorTests: XCTestCase {
    func testScaledEnvelope_givenHundredGramBase_whenFiftyGrams_thenHalvesMacros() {
        // Given
        let perHundred = NutrientMagnitudeEnvelope(kilocalories: 200, proteinGrams: 10, carbohydrateGrams: 20, lipidGrams: 8)
        // When
        let portion = NutrientPortionCalculator.scaledEnvelope(perHundredGrams: perHundred, servingGrams: 50)
        // Then
        XCTAssertEqual(portion.kilocalories, 100, accuracy: 0.001)
        XCTAssertEqual(portion.proteinGrams, 5, accuracy: 0.001)
        XCTAssertEqual(portion.carbohydrateGrams, 10, accuracy: 0.001)
        XCTAssertEqual(portion.lipidGrams, 4, accuracy: 0.001)
    }

    func testKilojouleFallback_given4184kJ_whenConverted_then1000Kilocalories() {
        // Given
        let kilojoules = 4184.0
        // When
        let kcal = NutrientPortionCalculator.kilocaloriesConvertedFromKilojoules(kilojoules)
        // Then
        XCTAssertEqual(kcal, 1000, accuracy: 0.01)
    }
}

final class EuropeanArticleNumberNormalizerTests: XCTestCase {
    func testNormalize_givenURLWithEAN13_whenParsed_thenDigitsOnly() {
        // Given
        let raw = "https://world.openfoodfacts.org/product/3017620422003/foo"
        // When
        let code = EuropeanArticleNumberNormalizer.normalizeRawOrURL(raw)
        // Then
        XCTAssertEqual(code, "3017620422003")
    }

    func testNormalize_givenUPC12_whenParsed_thenLeadingZero() {
        // Given
        let raw = "012345678905"
        // When
        let code = EuropeanArticleNumberNormalizer.normalizeRawOrURL(raw)
        // Then
        XCTAssertEqual(code, "0012345678905")
    }

    func testNormalize_givenShortJunk_whenParsed_thenNil() {
        // Given
        let raw = "abc12"
        // When
        let code = EuropeanArticleNumberNormalizer.normalizeRawOrURL(raw)
        // Then
        XCTAssertNil(code)
    }
}

final class SignalArchiveBinaryStoreTests: XCTestCase {
    func testRoundTrip_givenEnvelope_whenEncodedAndDecoded_thenEqual() throws {
        // Given
        var envelope = SignalVaultEnvelope.emptyFactory()
        envelope.onboardingCompleted = true
        envelope.localShelf = [sampleMerchandise()]
        // When
        let data = try SignalArchiveBinaryCodec.encodeEnvelope(envelope)
        let decoded = try SignalArchiveBinaryCodec.decodeEnvelope(from: data)
        // Then
        XCTAssertEqual(decoded.onboardingCompleted, true)
        XCTAssertEqual(decoded.localShelf.first?.stockKeepingUnit, "RS-TEST-1")
        XCTAssertEqual(String(data: data.prefix(4), encoding: .ascii), "RSG1")
    }
}

@MainActor
final class DailyIntakeDisplayInteractorTests: XCTestCase {
    private final class Spy: DailyIntakeDisplayPresentationLogic {
        var response: DailyIntakeDisplayModels.FetchDashboard.Response?
        func presentDashboard(response: DailyIntakeDisplayModels.FetchDashboard.Response) {
            self.response = response
        }
    }

    func testFetchDashboard_givenTodayEntry_whenFetched_thenTotalsMatchPortion() {
        // Given
        let merchandise = sampleMerchandise()
        let portion = NutrientPortionCalculator.scaledEnvelope(
            perHundredGrams: merchandise.perHundredEnvelope,
            servingGrams: 50
        )
        var envelope = SignalVaultEnvelope.emptyFactory()
        envelope.consumptionLog = [
            DailyConsumptionEntry(
                identifier: "E1",
                calendarDay: Calendar.current.startOfDay(for: Date()),
                laneKind: .pulseA,
                merchandise: merchandise,
                servingGrams: 50,
                computedMagnitudes: portion
            )
        ]
        let vault = InMemorySignalVault(envelope: envelope)
        let spy = Spy()
        let interactor = DailyIntakeDisplayInteractor(vault: vault)
        interactor.presenter = spy
        // When
        interactor.fetchDashboard(request: .init())
        // Then
        XCTAssertEqual(spy.response?.totals.kilocalories ?? -1, portion.kilocalories, accuracy: 0.001)
        XCTAssertEqual(spy.response?.entries.count, 1)
    }
}

@MainActor
final class CatalogSearchInteractorTests: XCTestCase {
    private final class Spy: CatalogSearchPresentationLogic {
        var shelf: CatalogSearchModels.FetchShelf.Response?
        var remote: CatalogSearchModels.SearchRemote.Response?
        var selected = false
        func presentShelf(response: CatalogSearchModels.FetchShelf.Response) { shelf = response }
        func presentRemote(response: CatalogSearchModels.SearchRemote.Response) { remote = response }
        func presentSelection(response: CatalogSearchModels.SelectMerchandise.Response) { selected = true }
    }

    private struct StubCatalog: CatalogMerchandiseFetching {
        let hits: [CatalogMerchandiseRecord]
        func searchMerchandise(matching query: String) async throws -> [CatalogMerchandiseRecord] { hits }
        func fetchMerchandise(europeanArticleNumber: String) async throws -> CatalogMerchandiseRecord {
            throw CatalogGatewayFailure.missingProduct
        }
    }

    func testFetchShelf_givenLocalStaples_whenRequested_thenPresenterReceivesShelf() {
        // Given
        var envelope = SignalVaultEnvelope.emptyFactory()
        envelope.localShelf = [sampleMerchandise()]
        let vault = InMemorySignalVault(envelope: envelope)
        let pipeline = SignalSessionPipeline()
        let spy = Spy()
        let interactor = CatalogSearchInteractor(vault: vault, catalog: StubCatalog(hits: []), pipeline: pipeline)
        interactor.presenter = spy
        // When
        interactor.fetchShelf(request: .init())
        // Then
        XCTAssertEqual(spy.shelf?.shelf.count, 1)
        XCTAssertEqual(spy.shelf?.shelf.first?.stockKeepingUnit, "RS-TEST-1")
    }

    func testSearchRemote_givenHits_whenQueryFires_thenPresenterGetsResults() async {
        // Given
        let vault = InMemorySignalVault()
        let pipeline = SignalSessionPipeline()
        let spy = Spy()
        let interactor = CatalogSearchInteractor(
            vault: vault,
            catalog: StubCatalog(hits: [sampleMerchandise()]),
            pipeline: pipeline
        )
        interactor.presenter = spy
        // When
        interactor.searchRemote(request: .init(query: "brick"))
        let deadline = Date().addingTimeInterval(1.5)
        while spy.remote == nil, Date() < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        // Then
        XCTAssertEqual(spy.remote?.results.count, 1)
        XCTAssertNil(spy.remote?.failureCaption)
    }

    func testSelectMerchandise_givenRecord_whenSelected_thenPipelineHoldsPending() {
        // Given
        let vault = InMemorySignalVault()
        let pipeline = SignalSessionPipeline()
        let spy = Spy()
        let interactor = CatalogSearchInteractor(vault: vault, catalog: StubCatalog(hits: []), pipeline: pipeline)
        interactor.presenter = spy
        let merchandise = sampleMerchandise()
        // When
        interactor.selectMerchandise(request: .init(merchandise: merchandise))
        // Then
        XCTAssertTrue(spy.selected)
        XCTAssertEqual(pipeline.pendingMerchandise?.stockKeepingUnit, merchandise.stockKeepingUnit)
        XCTAssertEqual(pipeline.pendingServingGrams, 50)
    }
}

@MainActor
final class ProductMerchandiseDetailInteractorTests: XCTestCase {
    private final class Spy: ProductMerchandiseDetailPresentationLogic {
        var wish: ProductMerchandiseDetailModels.QueueWish.Response?
        func presentPending(response: ProductMerchandiseDetailModels.FetchPending.Response) {}
        func presentAdjusted(response: ProductMerchandiseDetailModels.AdjustServing.Response) {}
        func presentWish(response: ProductMerchandiseDetailModels.QueueWish.Response) { wish = response }
    }

    func testQueueWish_givenFreshSKU_whenQueuedTwice_thenSecondIsDuplicate() {
        // Given
        let vault = InMemorySignalVault()
        let pipeline = SignalSessionPipeline()
        pipeline.pendingMerchandise = sampleMerchandise()
        let spy = Spy()
        let interactor = ProductMerchandiseDetailInteractor(vault: vault, pipeline: pipeline)
        interactor.presenter = spy
        // When
        interactor.queueWish(request: .init())
        let first = spy.wish?.alreadyPresent
        interactor.queueWish(request: .init())
        let second = spy.wish?.alreadyPresent
        // Then
        XCTAssertEqual(first, false)
        XCTAssertEqual(second, true)
        XCTAssertEqual(vault.loadEnvelope().wishLedger.count, 1)
    }
}

@MainActor
final class SlotAssignmentInteractorTests: XCTestCase {
    private final class Spy: SlotAssignmentPresentationLogic {
        var commit: SlotAssignmentModels.CommitAssignment.Response?
        func presentOptions(response: SlotAssignmentModels.FetchOptions.Response) {}
        func presentCommit(response: SlotAssignmentModels.CommitAssignment.Response) { commit = response }
    }

    func testCommit_givenMerchandise_whenTodayPulseA_thenLogGrows() {
        // Given
        let vault = InMemorySignalVault()
        let pipeline = SignalSessionPipeline()
        pipeline.pendingMerchandise = sampleMerchandise()
        pipeline.pendingServingGrams = 50
        let spy = Spy()
        let interactor = SlotAssignmentInteractor(vault: vault, pipeline: pipeline)
        interactor.presenter = spy
        // When
        interactor.commitAssignment(request: .init(laneKind: .pulseA, dayOffset: 0, destination: .todayEaten))
        // Then
        XCTAssertNil(spy.commit?.failure)
        XCTAssertEqual(vault.loadEnvelope().consumptionLog.count, 1)
        XCTAssertEqual(vault.loadEnvelope().consumptionLog.first?.laneKind, .pulseA)
    }

    func testCommit_givenNoise_whenHorizon_thenRejected() {
        // Given
        let vault = InMemorySignalVault()
        let pipeline = SignalSessionPipeline()
        pipeline.pendingMerchandise = sampleMerchandise()
        let spy = Spy()
        let interactor = SlotAssignmentInteractor(vault: vault, pipeline: pipeline)
        interactor.presenter = spy
        // When
        interactor.commitAssignment(request: .init(laneKind: .noise, dayOffset: 1, destination: .horizonPlan))
        // Then
        XCTAssertEqual(spy.commit?.failure, .noiseOnHorizon)
        XCTAssertTrue(vault.loadEnvelope().horizonPlans.isEmpty)
    }
}

@MainActor
final class PreferenceConfigurationInteractorTests: XCTestCase {
    private final class Spy: PreferenceConfigurationPresentationLogic {
        var preferences: PreferenceConfigurationSnapshot?
        func presentPreferences(response: PreferenceConfigurationModels.FetchPreferences.Response) {
            preferences = response.preferences
        }
    }

    func testPersist_givenCustomLabelsAndHorizon_whenWritten_thenVaultMatches() {
        // Given
        let vault = InMemorySignalVault()
        let spy = Spy()
        let interactor = PreferenceConfigurationInteractor(vault: vault)
        interactor.presenter = spy
        // When
        interactor.persistPreferences(
            request: .init(
                theme: .crimsonField,
                density: .compressed,
                horizonDays: 14,
                pulseA: "ALPHA",
                pulseB: "BETA",
                pulseC: "GAMMA",
                noise: "STATIC"
            )
        )
        // Then
        let prefs = vault.loadEnvelope().preferences
        XCTAssertEqual(prefs.themeIdentifier, .crimsonField)
        XCTAssertEqual(prefs.layoutDensity, .compressed)
        XCTAssertEqual(prefs.sanitizedHorizonDays(), 14)
        XCTAssertEqual(prefs.resolvedLabel(for: .pulseA), "ALPHA")
        XCTAssertEqual(prefs.resolvedLabel(for: .noise), "STATIC")
    }
}

@MainActor
final class GoalRevisionInteractorTests: XCTestCase {
    private final class Spy: GoalRevisionPresentationLogic {
        var persist: GoalRevisionModels.PersistGoals.Response?
        func presentGoals(response: GoalRevisionModels.FetchGoals.Response) {}
        func presentPersist(response: GoalRevisionModels.PersistGoals.Response) { persist = response }
    }

    func testPersist_givenValidTargets_whenWritten_thenNotRejected() {
        // Given
        let vault = InMemorySignalVault()
        let spy = Spy()
        let interactor = GoalRevisionInteractor(vault: vault)
        interactor.presenter = spy
        // When
        interactor.persistGoals(request: .init(energy: "2300", protein: "120", carbohydrate: "250", lipid: "75"))
        // Then
        XCTAssertEqual(spy.persist?.rejected, false)
        XCTAssertEqual(vault.loadEnvelope().preferences.dailyTargets.kilocalories, 2300)
    }

    func testPersist_givenGarbage_whenWritten_thenRejected() {
        // Given
        let vault = InMemorySignalVault()
        let spy = Spy()
        let interactor = GoalRevisionInteractor(vault: vault)
        interactor.presenter = spy
        // When
        interactor.persistGoals(request: .init(energy: "x", protein: "120", carbohydrate: "250", lipid: "75"))
        // Then
        XCTAssertEqual(spy.persist?.rejected, true)
        XCTAssertEqual(vault.loadEnvelope().preferences.dailyTargets.kilocalories, 2150)
    }
}

@MainActor
final class OnboardingSequenceInteractorTests: XCTestCase {
    private final class Spy: OnboardingSequencePresentationLogic {
        var pages = 0
        var completed = false
        func presentPages(response: OnboardingSequenceModels.FetchPages.Response) { pages = response.pages.count }
        func presentCompletion(response: OnboardingSequenceModels.CompleteSequence.Response) { completed = true }
    }

    func testComplete_givenFreshVault_whenLocked_thenOnboardingFlagSet() {
        // Given
        let vault = InMemorySignalVault()
        let spy = Spy()
        let interactor = OnboardingSequenceInteractor(vault: vault)
        interactor.presenter = spy
        // When
        interactor.fetchPages(request: .init())
        interactor.completeSequence(request: .init())
        // Then
        XCTAssertEqual(spy.pages, 4)
        XCTAssertTrue(spy.completed)
        XCTAssertTrue(vault.loadEnvelope().onboardingCompleted)
    }
}
