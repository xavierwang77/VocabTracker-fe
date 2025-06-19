import adapter from '@sveltejs/adapter-node';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';

const config = {
	preprocess: vitePreprocess(),
	kit: { 
		adapter: adapter({
			// 输出目录（可选）
			out: 'build'
		}),
		paths: {
			base: ''
		}
	}
};

export default config;
