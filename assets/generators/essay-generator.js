// generators/track-generator.js
const { inputRequired } = require('./utils')

module.exports = (plop) => {
  plop.setGenerator('essay entry', {
    prompts: [
      {
        type: 'input',
        name: 'title',
        message: ' Title: ',
        validate: inputRequired('title'),
      },
      {
        type: 'list',
        name: 'confidence',
        message: 'Confidence:',
        choices: [
          'believed',
          'semi-believed',
          'not-believed',
          'speculation',
          'fiction',
          'emotional',
          'log',
        ],
        validate: inputRequired('confidence'),
      },
      {
        type: 'list',
        name: 'status',
        message: 'Status:',
        choices: ['notes', 'draft', 'in progress', 'finished'],
        validate: inputRequired('status'),
      },
      {
        type: 'input',
        name: 'description',
        message: 'Description:',
        validate: inputRequired('description'),
      },
      {
        type: 'input',
        name: 'abstract',
        message: 'Abstract:',
        validate: inputRequired('abstract'),
      },
      {
        type: 'input',
        name: 'tags',
        message: 'Tags (separate with comma): ',
      },
    ],
    actions: (data) => {
      // Get the Current date
      data.createdDate = new Date().toISOString().split('T')[0]

      // Parse tags as a yaml array
      if (data.tags) {
        data.tags = `tags:\n - ${data.tags.split(',').join('\n - ')}`
      }

      return [
        {
          type: 'add',
          path:
            '../src/pages/essays/{{createdDate}}---{{dashCase title}}/index.md',
          templateFile: 'templates/essay-md.template',
        },
      ]
    },
  })
}
