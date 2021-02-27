// generators/track-generator.js
const { inputRequired } = require('./utils')

module.exports = (plop) => {
  plop.setGenerator('TIL journal entry', {
    prompts: [
      {
        type: 'input',
        name: 'title',
        message: ' Title: ',
        validate: inputRequired('title'),
      },
      {
        type: 'input',
        name: 'category',
        message: 'Category:',
        validate: inputRequired('category'),
      },
      {
        type: 'input',
        name: 'description',
        message: 'What did you learned? (240 chars):',
        validate: inputRequired('description'),
      },
      {
        type: 'input',
        name: 'tags',
        message: 'Tags (separate with comma): ',
      },
      {
        type: 'confirm',
        name: 'draft',
        message: 'Save as draft?',
        default: false,
      },
    ],
    actions: (data) => {
      // Get the Current date
      data.createdDate = new Date().toISOString().split('T')[0].replace(/-/g,"")

      // Parse tags as a yaml array
      if (data.tags) {
        data.tags = `"${data.tags.toLowerCase().split(',').join('","')}"`
      }

      return [
        {
          type: 'add',
          path:
            '../src/pages/journal/{{createdDate}}---{{dashCase title}}/index.md',
          templateFile: 'templates/journal-md.template',
        },
      ]
    },
  })
}
