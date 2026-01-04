module.exports = {
  pdf_options: {
    format: 'A4',
    margin: {
      top: '2cm',
      right: '2cm',
      bottom: '2cm',
      left: '2cm'
    },
    printBackground: true,
    preferCSSPageSize: true
  },
  css: `
@page {
  margin: 2cm;
}
body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
  font-size: 11pt;
  line-height: 1.6;
  color: #1f2933;
}
h1, h2 {
  page-break-before: avoid;
}
h1 {
  font-size: 18pt;
  margin: 0 0 12px 0;
  border-bottom: 2px solid #333;
  padding-bottom: 6px;
}
h2 {
  font-size: 14pt;
  margin: 18px 0 8px 0;
  color: #1f4b7f;
}
ul, ol {
  margin: 6px 0 10px 18px;
}
li {
  margin: 2px 0;
}
table {
  border-collapse: collapse;
  width: 100%;
  margin: 16px 0;
  font-size: 10.5pt;
}
th, td {
  border: 1px solid #ddd;
  padding: 6px 8px;
  text-align: left;
}
th {
  background-color: #f2f2f2;
  font-weight: bold;
}
.page-break {
  page-break-before: always;
}
`
};

