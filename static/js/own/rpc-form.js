/*
  Copyright (c) 2013, Alexey Kovrizhkin

  This document is licensed as free software under the terms of the
  MIT License: http://www.opensource.org/licenses/mit-license.php

  jQuery JSON-RPC form data transmitter
  project: P3Base, https://github.com/LeKovr/P3Base
  version: 1.0 (2013-08-27)
*/

//  Получение объекта со значениями полей формы
$.fn.serializeObject = function() {
  "use strict";
  var o = {};
  var a = this.serializeArray();
  $.each(a, function() {
    if (o[this.name]) {
      if (!o[this.name].push) {
        o[this.name] = [o[this.name]];
      }
      o[this.name].push(this.value || '');
    } else {
      o[this.name] = this.value || '';
    }
  });
  return o;
};

// Отправка данных формы по JSON-RPC и вывод переданных сервером ошибок
(function($, undefined) {
  $.extend({
    rpcForm: {
      init: function(options) {
        var defaults = {
          hasDisable:   true,         // блокировать input на время отправки данных
          hasOKEnable:  false,         // деблокировать input при успехе отправки данных
          hasError:     true,         // добавлять класс ошибки полям с ошибками
          errorPrefix:  'form-err-',  // префикс id div текста ошибки
          errorClass:   'has-error',  // класс, добавляемый при ошибке предку div текста ошибки
          statusDiv:    null,         // div статуса отправки данных
          fieldErrors: {              // текст ошибки валидации поля
            "1001": "Значение должно быть задано",
            "1002": "Пароли не совпадают",
            "1004": "Логин не найден"
          },
          formErrors: {               // текст ошибки отправки данных
            "-32602": "Ошибка валидации полей формы"
          }
        };
        this._validateOptions(options);
        this.options = $.extend(defaults, options);
      },
      call: function(method, form, cbOk, cbError) {
        // прямой вызов rpc метода
        // method   - имя RPC метода
        // form     - форма, данные которой отправлять (аргументы метода)
        // cbOk     - коллбэк успешного вызова метода, вызывается как cbOk(data.result)
        // cbError  - коллбэк ошибки вызова метода, вызывается как cbError(data.error)
        var self = this;
        var p = $(form).serializeObject();
        if (self.options.hasError) {
          // удалить класс ошибки с полей перед отправкой данных
          self.options.statusDiv.parent().children('.form-group').removeClass(self.options.errorClass);
        }
        if (self.options.hasDisable) {
          // блокировать input на время отправки данных
          $.each($(form)[0].elements, function(k, v) {
            if ($(this).attr('disabled') !== 'disabled') $(this).addClass('tmpDisabled').attr('disabled', 'disabled');
          });
        }
        $.jsonRPC.request(method, { 
          params: p,
          success: function(data) {
            // Коллбэк успешного вызова RPC метода
            if (self.options.hasDisable && self.options.hasOKEnable) {
              // деблокировать input
              $.each($(form)[0].elements, function(k, v) {
                if ($(this).hasClass('tmpDisabled')) $(this).removeAttr('disabled').removeClass('tmpDisabled');
              });
            }
            if (cbOk) cbOk(data.result);
          },
          error: function(data) {
            // Коллбэк ошибки вызова RPC метода
            if (self.options.hasDisable) {
              // деблокировать input
              $.each($(form)[0].elements, function(k, v) {
                if ($(this).hasClass('tmpDisabled')) $(this).removeAttr('disabled').removeClass('tmpDisabled');
              });
            }
            // При ошибке -32602, 'Invalid params'
            // в data передается массив ошибок полей, которые имеют структуру
            // code     - код ошибки
            // param    - имя параметра
            // message  - тест ошибки
            // если код ошибки поля есть в self.options.fieldErrors, производится подмена текста ошибки
            if (self.options.hasError && data.error !== undefined && data.error.code == -32602) {
              $.each(data.error.data, function(k,v) {
                // для каждой ошибки - вывести текст и подсветить поле добавлением класса self.options.errorClass
                $('#' + self.options.errorPrefix + v.param)
                  .html(self.options.fieldErrors[v.code] || v.message)
                  .parent().addClass(self.options.errorClass);
              });
            }
            // Вывести статус отправки данных
            // если код ошибки вызова есть в self.options.formErrors, производится подмена текста ошибки
            // иначе - выводится код ошибки
            self.options.statusDiv.html(self.options.formErrors[data.error.code] || 'Ошибка ' + data.error.code); //  || data.error.message
            if (cbError) cbError(data.error);
          }
        });
        return false;
      },
      on: function(method, event, cbOk, cbError) {
        // вызов rpc метода по submit формы
        // method   - имя RPC метода
        // event    - событие формы, данные которой отправлять (аргументы метода)
        // cbOk     - коллбэк успешного вызова метода, вызывается как cbOk(data.result)
        // cbError  - коллбэк ошибки вызова метода, вызывается как cbError(data.error)
        var self = this;
        self.call(method, event.target, cbOk, cbError);
        return false;
      },
      _validateOptions: function(options) {
        // Внутренний метод - валидация опций
        if(options.statusDiv && typeof(options.statusDiv) !== 'object') {
            throw("statusDiv must be an object");
        }
      },      
    }
  });
})(jQuery);