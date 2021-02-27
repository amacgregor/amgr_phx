// generators/track-generator.js
const { inputRequired } = require('./utils')

module.exports = (plop) => {
  plop.setGenerator('post entry', {
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
        message: 'Description:',
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
            '../../content/posts/{{createdDate}}-{{dashCase title}}.md',
          templateFile: 'templates/post-md.template',
        },
      ]
    },
  })
}
