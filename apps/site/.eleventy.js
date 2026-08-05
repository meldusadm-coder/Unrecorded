export default function (eleventyConfig) {
  eleventyConfig.addPassthroughCopy({ "src/assets": "assets" });
  eleventyConfig.addPassthroughCopy({ "src/robots.txt": "robots.txt" });
  eleventyConfig.addPassthroughCopy({ "src/app-ads.txt": "app-ads.txt" });
  eleventyConfig.addPassthroughCopy({ "src/_headers": "_headers" });
  eleventyConfig.addPassthroughCopy({ "src/.well-known": ".well-known" });

  eleventyConfig.addFilter("isoDate", (value) => {
    const date = value instanceof Date ? value : new Date(value);
    if (Number.isNaN(date.valueOf())) {
      throw new Error(`Invalid date for isoDate filter: ${value}`);
    }
    return date.toISOString().slice(0, 10);
  });

  eleventyConfig.addFilter("json", (value) => JSON.stringify(value));

  eleventyConfig.addCollection("sitemapPages", (collectionApi) =>
    collectionApi
      .getAll()
      .filter((item) => item.data.canonicalPath && item.data.sitemap !== false)
      .sort((a, b) => {
        const priority = (b.data.sitemapPriority ?? 0.5) - (a.data.sitemapPriority ?? 0.5);
        if (priority !== 0) return priority;
        return a.data.canonicalPath.localeCompare(b.data.canonicalPath);
      }),
  );

  return {
    dir: {
      input: "src",
      includes: "_includes",
      data: "_data",
      output: "_site",
    },
    htmlTemplateEngine: "njk",
    markdownTemplateEngine: "njk",
    templateFormats: ["njk", "html", "md"],
  };
}
