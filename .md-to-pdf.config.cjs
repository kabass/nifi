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
  line-height: 1.6;
  color: #333;
}
h1 {
  page-break-before: always;
  border-bottom: 2px solid #333;
  padding-bottom: 10px;
}
h2 {
  page-break-before: always;
  margin-top: 30px;
  color: #2c3e50;
}
table {
  border-collapse: collapse;
  width: 100%;
  margin: 20px 0;
}
th, td {
  border: 1px solid #ddd;
  padding: 8px;
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

