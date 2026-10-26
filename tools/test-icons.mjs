import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import test from 'node:test';
import {iconPaths} from '../preview/assets/icons.js';

globalThis.location = {hash: ''};
globalThis.localStorage = {getItem: () => null};
const {icon, views} = await import('../preview/views.js');

test('every sprite icon contains inline geometry with a viewport', async () => {
    const sprite = await readFile(new URL('../preview/assets/icons.svg', import.meta.url), 'utf8');
    const names = [...sprite.matchAll(/id="i-([^"]+)"/g)].map(match => match[1]);
    assert.equal(names.length, 58);
    assert.deepEqual(names.sort(), Object.keys(iconPaths).sort());
    for (const name of names) {
        const svg = icon(name);
        assert.match(svg, /viewBox="0 0 24 24"/);
        assert.match(svg, /<(path|circle|rect|line|polyline|polygon|ellipse)\b/);
        assert.doesNotMatch(svg, /<use\b|display:none|undefined/);
    }
});

test('all preview screens render their icons without external SVG references', () => {
    for (const [route, render] of Object.entries(views)) {
        const html = render();
        const icons = [...html.matchAll(/<svg class="icon"[^>]*>([\s\S]*?)<\/svg>/g)];
        assert.ok(icons.length > 0, route);
        for (const match of icons) {
            assert.match(match[1], /<(path|circle|rect|line|polyline|polygon|ellipse)\b/, route);
        }
        assert.doesNotMatch(html, /<use\b|icons\.svg#/, route);
    }
});

test('an unknown icon has a visible fallback', () => {
    assert.ok(icon('unknown-icon').includes(iconPaths['circle-help']));
});
