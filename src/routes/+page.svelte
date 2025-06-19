<div class="container">
	{#if currentState === 'start'}
		<button class="start-button" onclick={startVocabTest}>
			开始估算词汇量
		</button>
	{:else if currentState === 'loading'}
		<div class="loading">
			<div class="spinner"></div>
			<p>正在加载词汇...</p>
		</div>
	{:else if currentState === 'testing'}
		<div class="word-test">
			<div class="progress">
				<div class="progress-bar" style="width: {(currentWordIndex / totalWords) * 100}%"></div>
				<span class="progress-text">{currentWordIndex + 1} / {totalWords}</span>
			</div>
			<div class="word-card">
				<h2 class="word">{currentWord?.head_word}</h2>
				<p class="phonetic">
					{#if currentWord?.us_phone}
						美: /{currentWord.us_phone}/
					{/if}
					{#if currentWord?.uk_phone}
						英: /{currentWord.uk_phone}/
					{/if}
				</p>
				<div class="buttons">
					<button class="know-button" onclick={() => answerWord(true)}>认识</button>
					<button class="unknown-button" onclick={() => answerWord(false)}>不认识</button>
				</div>
			</div>
		</div>
	{:else if currentState === 'result'}
		<div class="result">
			<h2>测试完成！</h2>
			<div class="result-stats">
				{#each Object.entries(testResults) as [level, stats]}
					<div class="level-result">
						<h3>{getLevelName(level)}</h3>
						<p>认识: {stats.known} / {stats.total} ({Math.round((stats.known / stats.total) * 100)}%)</p>
					</div>
				{/each}
			</div>
			<button class="restart-button" onclick={resetTest}>重新测试</button>
		</div>
	{:else if currentState === 'estimating'}
		<div class="loading">
			<div class="spinner"></div>
			<p>正在估算词汇量...</p>
		</div>
	{:else if currentState === 'estimate-result'}
		<div class="estimate-result">
			<h2>词汇量估算结果</h2>
			{#if estimateResult}
				<div class="estimate-card">
					<div class="vocabulary-count">
						<span class="count-number">{estimateResult.estimated_vocabulary.toLocaleString()}</span>
						<span class="count-label">词汇量</span>
					</div>
					<div class="confidence">
						<p><strong>置信度:</strong> {estimateResult.confidence_level}</p>
					</div>
					{#if estimateResult.recommendations && estimateResult.recommendations.length > 0}
						<div class="recommendations">
							<h3>学习建议</h3>
							<ul>
								{#each estimateResult.recommendations as recommendation}
									<li>{recommendation}</li>
								{/each}
							</ul>
						</div>
					{/if}
				</div>
				<div class="result-actions">
					<button class="view-details-button" onclick={() => currentState = 'result'}>查看详细结果</button>
					<button class="restart-button" onclick={resetTest}>重新测试</button>
				</div>
			{/if}
		</div>
	{/if}
</div>

<script lang="ts">
	// 词汇数据接口定义
	interface Word {
		id: number;
		word_rank: number;
		head_word: string;
		translation: string;
		book_id: string;
		word_id: string;
		us_phone: string;
		uk_phone: string;
	}

	interface VocabularyResponse {
		cet4: Word[];
		cet6: Word[];
		kaoyan: Word[];
		level4: Word[];
		level8: Word[];
		total_count: number;
	}

	interface WordWithAnswer extends Word {
		level: string;
		known?: boolean;
	}

	interface LevelStats {
		known: number;
		total: number;
	}

	// 估算请求接口
	interface EstimateRequest {
		cet4: { known: number; total: number };
		cet6: { known: number; total: number };
		kaoyan: { known: number; total: number };
		level4: { known: number; total: number };
		level8: { known: number; total: number };
	}

	// 估算响应接口
	interface EstimateResponse {
		estimated_vocabulary: number;
		breakdown: Record<string, any>;
		confidence_level: string;
		recommendations: string[];
	}

	// 状态管理
	let currentState: 'start' | 'loading' | 'testing' | 'result' | 'estimating' | 'estimate-result' = $state('start');
	let allWords: WordWithAnswer[] = $state([]);
	let currentWordIndex: number = $state(0);
	let currentWord: WordWithAnswer | null = $state(null);
	let totalWords: number = $state(0);
	let testResults: Record<string, LevelStats> = $state({});
	let estimateResult: EstimateResponse | null = $state(null);

	/**
	 * 开始词汇量测试
	 */
	async function startVocabTest(): Promise<void> {
		currentState = 'loading';
		try {
			const response = await fetch('/api/vocabulary/random');
			if (!response.ok) {
				throw new Error(`HTTP error! status: ${response.status}`);
			}
			const data: VocabularyResponse = await response.json();
			
			// 将所有词汇合并为一个数组，并添加级别标识
			allWords = [
				...data.cet4.map(word => ({ ...word, level: 'cet4' })),
				...data.cet6.map(word => ({ ...word, level: 'cet6' })),
				...data.kaoyan.map(word => ({ ...word, level: 'kaoyan' })),
				...data.level4.map(word => ({ ...word, level: 'level4' })),
				...data.level8.map(word => ({ ...word, level: 'level8' }))
			];
			
			totalWords = allWords.length;
			currentWordIndex = 0;
			currentWord = allWords[0] || null;
			
			// 初始化测试结果统计
			testResults = {
				cet4: { known: 0, total: data.cet4.length },
				cet6: { known: 0, total: data.cet6.length },
				kaoyan: { known: 0, total: data.kaoyan.length },
				level4: { known: 0, total: data.level4.length },
				level8: { known: 0, total: data.level8.length }
			};
			
			currentState = 'testing';
		} catch (error) {
			console.error('获取词汇数据失败:', error);
			alert('获取词汇数据失败，请稍后重试');
			currentState = 'start';
		}
	}

	/**
	 * 回答当前单词
	 * @param known 是否认识该单词
	 */
	function answerWord(known: boolean): void {
		if (!currentWord) return;
		
		// 记录答案
		currentWord.known = known;
		
		// 更新统计
		if (known) {
			testResults[currentWord.level].known++;
		}
		
		// 进入下一个单词
		currentWordIndex++;
		
		if (currentWordIndex < totalWords) {
			currentWord = allWords[currentWordIndex];
		} else {
			// 测试完成，发送估算请求
			currentState = 'result';
			submitEstimate();
		}
	}

	/**
	 * 提交估算请求
	 */
	async function submitEstimate(): Promise<void> {
		currentState = 'estimating';
		try {
			const requestData: EstimateRequest = {
				cet4: { known: testResults.cet4.known, total: testResults.cet4.total },
				cet6: { known: testResults.cet6.known, total: testResults.cet6.total },
				kaoyan: { known: testResults.kaoyan.known, total: testResults.kaoyan.total },
				level4: { known: testResults.level4.known, total: testResults.level4.total },
				level8: { known: testResults.level8.known, total: testResults.level8.total }
			};

			const response = await fetch('/api/vocabulary/estimate', {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json'
				},
				body: JSON.stringify(requestData)
			});

			if (!response.ok) {
				throw new Error(`HTTP error! status: ${response.status}`);
			}

			estimateResult = await response.json();
			currentState = 'estimate-result';
		} catch (error) {
			console.error('提交估算请求失败:', error);
			alert('估算请求失败，请稍后重试');
			currentState = 'result';
		}
	}

	/**
	 * 获取级别中文名称
	 * @param level 级别代码
	 * @returns 中文名称
	 */
	function getLevelName(level: string): string {
		const levelNames: Record<string, string> = {
			cet4: 'CET-4',
			cet6: 'CET-6',
			kaoyan: '考研',
			level4: '专四',
			level8: '专八'
		};
		return levelNames[level] || level;
	}

	/**
	 * 重置测试
	 */
	function resetTest(): void {
		currentState = 'start';
		allWords = [];
		currentWordIndex = 0;
		currentWord = null;
		totalWords = 0;
		testResults = {};
		estimateResult = null;
	}
</script>

<style>
	.container {
		display: flex;
		justify-content: center;
		align-items: center;
		height: 100vh;
		padding: 20px;
	}

	/* 开始按钮样式 */
	.start-button {
		padding: 16px 32px;
		font-size: 18px;
		font-weight: 600;
		color: white;
		background: var(--primary-color, linear-gradient(135deg, #9ACD32 0%, #7CB342 100%));
		border: none;
		border-radius: var(--border-radius-md, 8px);
		cursor: pointer;
		transition: transform 0.2s ease, box-shadow 0.2s ease, filter 0.2s ease;
		box-shadow: var(--shadow-medium, 0 4px 8px rgba(0, 0, 0, 0.2));
		position: relative;
		overflow: hidden;
	}

	.start-button::before {
		content: '';
		position: absolute;
		top: 0;
		left: 0;
		width: 100%;
		height: 100%;
		background: linear-gradient(135deg, rgba(255,255,255,0.1) 0%, rgba(255,255,255,0.05) 100%);
		opacity: 0;
		transition: opacity 0.2s ease;
		pointer-events: none;
	}

	.start-button:hover {
		transform: translateY(-3px);
		box-shadow: 0 8px 16px rgba(0, 0, 0, 0.25);
		filter: brightness(1.05);
	}

	.start-button:hover::before {
		opacity: 1;
	}

	.start-button:active {
		transform: translateY(-1px);
		box-shadow: 0 4px 8px rgba(0, 0, 0, 0.2);
		filter: brightness(0.95);
	}

	/* 加载状态样式 */
	.loading {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 20px;
	}

	.spinner {
		width: 40px;
		height: 40px;
		border: 4px solid rgba(124, 179, 66, 0.3);
		border-top: 4px solid var(--primary-hover, #7CB342);
		border-radius: 50%;
		animation: spin 1s linear infinite;
	}

	@keyframes spin {
		0% { transform: rotate(0deg); }
		100% { transform: rotate(360deg); }
	}

	.loading p {
		color: var(--text-secondary, #666666);
		font-size: 16px;
		margin: 0;
	}

	/* 测试界面样式 */
	.word-test {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 30px;
		max-width: 500px;
		width: 100%;
	}

	.progress {
		width: 100%;
		position: relative;
		height: 8px;
		background: rgba(124, 179, 66, 0.2);
		border-radius: 4px;
		overflow: hidden;
	}

	.progress-bar {
		height: 100%;
		background: var(--primary-color, linear-gradient(135deg, #9ACD32 0%, #7CB342 100%));
		transition: width 0.3s ease;
		border-radius: 4px;
	}

	.progress-text {
		position: absolute;
		top: -25px;
		right: 0;
		font-size: 14px;
		color: var(--text-secondary, #666666);
	}

	.word-card {
		background: white;
		border-radius: var(--border-radius-lg, 12px);
		padding: 40px;
		box-shadow: var(--shadow-medium, 0 4px 8px rgba(0, 0, 0, 0.2));
		text-align: center;
		width: 100%;
	}

	.word {
		font-size: 36px;
		font-weight: 700;
		color: var(--text-primary, #333333);
		margin: 0 0 10px 0;
	}

	.phonetic {
		font-size: 16px;
		color: var(--text-secondary, #666666);
		margin: 0 0 30px 0;
		font-style: italic;
	}

	.buttons {
		display: flex;
		gap: 20px;
		justify-content: center;
	}

	.know-button, .unknown-button {
		padding: 12px 24px;
		font-size: 16px;
		font-weight: 600;
		border: none;
		border-radius: var(--border-radius-md, 8px);
		cursor: pointer;
		transition: all 0.2s ease;
		min-width: 100px;
	}

	.know-button {
		background: var(--success-color, #28a745);
		color: white;
	}

	.know-button:hover {
		background: #218838;
		transform: translateY(-2px);
		box-shadow: 0 4px 8px rgba(40, 167, 69, 0.3);
	}

	.unknown-button {
		background: var(--error-color, #ff4545);
		color: white;
	}

	.unknown-button:hover {
		background: var(--error-hover, #e03c3c);
		transform: translateY(-2px);
		box-shadow: 0 4px 8px rgba(255, 69, 69, 0.3);
	}

	/* 结果页面样式 */
	.result {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 30px;
		max-width: 600px;
		width: 100%;
	}

	.result h2 {
		font-size: 28px;
		color: var(--text-primary, #333333);
		margin: 0;
	}

	.result-stats {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
		gap: 20px;
		width: 100%;
	}

	.level-result {
		background: white;
		border-radius: var(--border-radius-md, 8px);
		padding: 20px;
		box-shadow: var(--shadow-light, 0 2px 2px rgba(0, 0, 0, 0.05));
		text-align: center;
	}

	.level-result h3 {
		font-size: 18px;
		color: var(--text-primary, #333333);
		margin: 0 0 10px 0;
	}

	.level-result p {
		font-size: 14px;
		color: var(--text-secondary, #666666);
		margin: 0;
	}

	.restart-button {
		padding: 12px 24px;
		font-size: 16px;
		font-weight: 600;
		color: white;
		background: var(--primary-color, linear-gradient(135deg, #9ACD32 0%, #7CB342 100%));
		border: none;
		border-radius: var(--border-radius-md, 8px);
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.restart-button:hover {
		filter: brightness(1.1);
		transform: translateY(-2px);
		box-shadow: 0 4px 8px rgba(124, 179, 66, 0.3);
	}

	/* 估算结果页面样式 */
	.estimate-result {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 30px;
		max-width: 600px;
		width: 100%;
	}

	.estimate-result h2 {
		font-size: 28px;
		color: var(--text-primary, #333333);
		margin: 0;
		text-align: center;
	}

	.estimate-card {
		background: white;
		border-radius: var(--border-radius-lg, 12px);
		padding: 40px;
		box-shadow: var(--shadow-medium, 0 4px 8px rgba(0, 0, 0, 0.2));
		text-align: center;
		width: 100%;
	}

	.vocabulary-count {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 10px;
		margin-bottom: 30px;
		padding: 20px;
		background: linear-gradient(135deg, rgba(154, 205, 50, 0.1) 0%, rgba(124, 179, 66, 0.1) 100%);
		border-radius: var(--border-radius-md, 8px);
	}

	.count-number {
		font-size: 48px;
		font-weight: 700;
		color: var(--primary-color, #7CB342);
		line-height: 1;
	}

	.count-label {
		font-size: 18px;
		color: var(--text-secondary, #666666);
		font-weight: 500;
	}

	.confidence {
		margin-bottom: 30px;
		padding: 15px;
		background: rgba(40, 167, 69, 0.1);
		border-radius: var(--border-radius-md, 8px);
	}

	.confidence p {
		margin: 0;
		font-size: 16px;
		color: var(--text-primary, #333333);
	}

	.recommendations {
		text-align: left;
	}

	.recommendations h3 {
		font-size: 20px;
		color: var(--text-primary, #333333);
		margin: 0 0 15px 0;
		text-align: center;
	}

	.recommendations ul {
		list-style: none;
		padding: 0;
		margin: 0;
	}

	.recommendations li {
		padding: 10px 0;
		border-bottom: 1px solid rgba(0, 0, 0, 0.1);
		color: var(--text-secondary, #666666);
		line-height: 1.5;
	}

	.recommendations li:last-child {
		border-bottom: none;
	}

	.recommendations li::before {
		content: '💡';
		margin-right: 10px;
	}

	.result-actions {
		display: flex;
		gap: 15px;
		justify-content: center;
		flex-wrap: wrap;
	}

	.view-details-button {
		padding: 12px 24px;
		font-size: 16px;
		font-weight: 600;
		color: var(--primary-color, #7CB342);
		background: white;
		border: 2px solid var(--primary-color, #7CB342);
		border-radius: var(--border-radius-md, 8px);
		cursor: pointer;
		transition: all 0.2s ease;
	}

	.view-details-button:hover {
		background: var(--primary-color, #7CB342);
		color: white;
		transform: translateY(-2px);
		box-shadow: 0 4px 8px rgba(124, 179, 66, 0.3);
	}

	/* 响应式设计 */
	@media (max-width: 768px) {
		.container {
			padding: 10px;
		}

		.word-card {
			padding: 30px 20px;
		}

		.word {
			font-size: 28px;
		}

		.buttons {
			flex-direction: column;
			align-items: center;
		}

		.know-button, .unknown-button {
			width: 100%;
			max-width: 200px;
		}

		.result-stats {
			grid-template-columns: 1fr;
		}

		.estimate-card {
			padding: 30px 20px;
		}

		.count-number {
			font-size: 36px;
		}

		.result-actions {
			flex-direction: column;
			align-items: center;
		}

		.view-details-button, .restart-button {
			width: 100%;
			max-width: 250px;
		}
	}
</style>
