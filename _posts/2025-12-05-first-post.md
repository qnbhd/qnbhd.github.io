---
title: First post
author: Templin Konstantin
category: programming
layout: post
---

My first test blog post with typography & code blocks


## Headings

<!-- markdownlint-capture -->
<!-- markdownlint-disable -->
# H1 — heading
{: .mt-4 .mb-0 }

## H2 — heading
{: data-toc-skip='' .mt-4 .mb-0 }

### H3 — heading
{: data-toc-skip='' .mt-4 .mb-0 }

#### H4 — heading
{: data-toc-skip='' .mt-4 }
<!-- markdownlint-restore -->

## Paragraph

Quisque egestas convallis ipsum, ut sollicitudin risus tincidunt a. Maecenas interdum malesuada egestas. Duis consectetur porta risus, sit amet vulputate urna facilisis ac. Phasellus semper dui non purus ultrices sodales. Aliquam ante lorem, ornare a feugiat ac, finibus nec mauris. Vivamus ut tristique nisi. Sed vel leo vulputate, efficitur risus non, posuere mi. Nullam tincidunt bibendum rutrum. Proin commodo ornare sapien. Vivamus interdum diam sed sapien blandit, sit amet aliquam risus mattis. Nullam arcu turpis, mollis quis laoreet at, placerat id nibh. Suspendisse venenatis eros eros.

## Lists

### Ordered list

1. Firstly
2. Secondly
3. Thirdly

### Unordered list

- Chapter
  - Section
    - Paragraph

### ToDo list

- [ ] Job
  - [x] Step 1
  - [x] Step 2
  - [ ] Step 3

### Description list

Sun
: the star around which the earth orbits

Moon
: the natural satellite of the earth, visible by reflected light from the sun

## Block Quote

> This line shows the _block quote_.

## Prompts

<!-- markdownlint-capture -->
<!-- markdownlint-disable -->
> An example showing the `tip` type prompt.
{: .prompt-tip }

> An example showing the `info` type prompt.
{: .prompt-info }

> An example showing the `warning` type prompt.
{: .prompt-warning }

> An example showing the `danger` type prompt.
{: .prompt-danger }
<!-- markdownlint-restore -->

## Tables

| Company                      | Contact          | Country |
| :--------------------------- | :--------------- | ------: |
| Alfreds Futterkiste          | Maria Anders     | Germany |
| Island Trading               | Helen Bennett    |      UK |
| Magazzini Alimentari Riuniti | Giovanni Rovelli |   Italy |

## Links

<http://127.0.0.1:4000>

## Footnote

Click the hook will locate the footnote[^footnote], and here is another footnote[^fn-nth-2].

## Inline code

This is an example of `Inline Code`.

## Filepath

Here is the `/path/to/the/file.extend`{: .filepath}.

## Code blocks

### Common

```text
This is a common code snippet, without syntax highlight and line number.
```

### Rust

```rust
use redis::{AsyncCommands, Value};
use serde::Deserialize;

#[derive(Debug, Deserialize)]
pub struct Job {
    pub job_id: String,
    pub source: String,
    pub language: String,
    pub input: String,
}

```

### Zig

```zig
pub const Cursor = struct {
    table: *executor.Table,
    page_num: u32,
    cell_num: u32,
    end_of_table: bool,

    pub fn tableFind(table: *executor.Table, key: u32, alloc: std.mem.Allocator) !*Cursor {
        const root_page_num = table.root_page_num;
        const node = try table.pager.getPage(root_page_num);

        const ty = executor.getNodeType(node);
        return switch (ty) {
            .leaf => executor.leafNodeFind(table, root_page_num, key, alloc),
            .internal => executor.internalNodeFind(table, root_page_num, key, alloc),
        };
    }

    pub fn advance(self: *Cursor) void {
        const node = self.table.pager.getPage(self.page_num) catch @panic("Bad");
        self.cell_num += 1;
        if (self.cell_num >= executor.leafNumCells(node).*) {
            // Advance to next leaf node
            const next_page_num = executor.leafNextLeaf(node).*;
            if (next_page_num == 0) {
                // This was rightmost leaf
                self.end_of_table = true;
            } else {
                self.page_num = next_page_num;
                self.cell_num = 0;
            }
        }
    }
};

```

### Specific filename

```sass
@import
  "colors/light-typography",
  "colors/dark-typography";
```
{: file='_sass/jekyll-theme-chirpy.scss'}


## Reverse Footnote

[^footnote]: The footnote source
[^fn-nth-2]: The 2nd footnote source
