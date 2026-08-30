extends GutTest


func test_load_pool_reads_the_audited_baza_file() -> void:
	var repository := BazaWordRepository.new()
	var pool := repository.load_pool()
	assert_eq(pool.answers().size(), 18064)
	assert_eq(pool.answers()[0], "ДУПЉИ")
	assert_eq(pool.answers()[pool.answers().size() - 1], "ПАДЕЛ")
	assert_true(pool.contains("ДУПЉИ"))
	assert_true(pool.contains("ПАДЕЛ"))
	assert_eq(pool.fingerprint().length(), 64)
